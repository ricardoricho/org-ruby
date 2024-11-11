require 'rubypants'

module Orgmode

  ##
  ##  Simple routines for loading / saving an ORG file.
  ##

  class Parser

    # All of the lines of the orgmode file
    attr_reader :lines

    # These are any lines before the first headline
    attr_reader :header_lines

    # Regexp that recognizes words in custom_keywords.
    def custom_keyword_regexp
      return nil if document.custom_keywords.empty?

      keywords = document.custom_keywords.join('|')
      Regexp.new("^(#{keywords})\$")
    end

    # A set of tags that, if present on any headlines in the org-file, means
    # only those headings will get exported.
    def export_select_tags
      buffer_settings.fetch("EXPORT_SELECT_TAGS", "").split
    end

    # A set of tags that, if present on any headlines in the org-file, means
    # that subtree will not get exported.
    def export_exclude_tags
      buffer_settings.fetch("EXPORT_EXCLUDE_TAGS", "").split
    end

    # Returns true if we are to export todo keywords on headings.
    def export_todo?
      "t" == options["todo"]
    end

    # Returns true if we are to export footnotes
    def export_footnotes?
      "nil" != options["f"]
    end

    # Returns true if we are to export heading numbers.
    def export_heading_number?
      "t" == options["num"]
    end

    # Should we skip exporting text before the first heading?
    def skip_header_lines?
      "t" == options["skip"]
    end

    # Should we export tables? Defaults to true, must be overridden
    # with an explicit "nil"
    def export_tables?
      "nil" != options["|"]
    end

    # Should we export sub/superscripts? (_{foo}/^{foo})
    # only {} mode is currently supported.
    def use_sub_superscripts?
      "nil" != options["^"]
    end

    # Support for left to right when buffer or parser option.
    def left_to_right?
      options["ltr"] == 't' || @parser_options[:ltr]
    end

    def initialize_lines(lines)
      return lines if lines.is_a? Array
      return lines.split("\n") if lines.is_a? String

      raise "Unsupported type for +lines+: #{lines.class}"
    end

    # I can construct a parser object either with an array of lines
    # or with a single string that I will split along \n boundaries.
    def initialize(lines, options = {})
      @lines = initialize_lines(lines)
      @current_headline = nil
      @document = Orgmode::Elements::Document.new
      @header_lines = []
      parse_options options
      parse_lines @lines
    end

    def buffer_settings
      document&.buffer_settings
    end

    def custom_keywords
      document&.custom_keywords
    end

    def headlines
      document.headlines
    end

    def options
      document&.options
    end

    # Check include file availability and permissions
    def check_include_file(file_path)
      root_file_path =
        File.expand_path(ENV.fetch('ORG_RUBY_INCLUDE_ROOT', ''), file_path)
      File.exist?(root_file_path)
    end

    def parse_lines(lines)
      mode = :normal
      previous_line = nil
      table_header_set = false
      lines.each do |text|
        line = Line.new text, self

        if @parser_options[:allow_include_files] && line.include_file? &&
           !line.include_file_path.nil?
            next unless check_include_file(line.include_file_path)
            include_file(line)
        end

        # Store link abbreviations
        document.store_link_abbreviation(line)
        # Store footnotes
        document.store_footnote(line)
        # Store targets
        document.store_target(line)

        if (line.end_block? && [line.paragraph_type, :comment].include?(mode)) ||
           (line.property_drawer_end_block? && (mode == :property_drawer))
          mode = :normal
        end

        if %i[normal quote center].include?(mode)
          if line.headline?
            line = Headline.new(line.to_s, self, @parser_options[:offset])
          elsif line.table_separator?
            if previous_line && (previous_line.paragraph_type == :table_row) && !table_header_set
              previous_line.assigned_paragraph_type = :table_header
              table_header_set = true
            end
          end
          table_header_set = false unless line.table?
        end

        if %i[example html src].include?(mode)
          if previous_line
            set_name_for_code_block(previous_line, line)
            set_mode_for_results_block_contents(previous_line, line)
          end

          # As long as we stay in code mode, force lines to be code.
          # Don't try to interpret structural items, like headings and tables.
          line.assigned_paragraph_type = :code
        end

        if mode == :normal
          if line.headline?
            document.store_headline(line)
            @current_headline = line
          end
          document.store_buffer_settings(line)

          mode = line.paragraph_type if line.begin_block?

          if previous_line
            set_name_for_code_block(previous_line, line)
            set_mode_for_results_block_contents(previous_line, line)

            mode = :property_drawer if previous_line.property_drawer_begin_block?
          end

          # We treat the results code block differently since the exporting can be omitted
          if line.begin_block?
            @next_results_block_should_be_exported = line.results_block_should_be_exported?
          end
        end

        if (mode == :property_drawer) && @current_headline
          @current_headline.store_property(line.property_drawer_item?)
        end

        unless mode == :comment
          if @current_headline
            @current_headline.push_body_line(line)
          else
            @header_lines.push(line)
          end
        end

        previous_line = line
      end
    end

    def include_file(line)
      include_data = get_include_data line
      include_lines = initialize_lines include_data
      parse_lines include_lines
    end

    # Get include data, when #+INCLUDE tag is used
    # @link http://orgmode.org/manual/Include-files.html
    def get_include_data(line)
      return IO.read(line.include_file_path) if line.include_file_options.nil?

      case line.include_file_options[0]
      when ':lines'
        # Get options
        include_file_lines = line.include_file_options[1].gsub('"', '').split('-')
        include_file_lines[0] = include_file_lines[0].empty? ? 1 : include_file_lines[0].to_i
        include_file_lines[1] = include_file_lines[1].to_i unless include_file_lines[1].nil?

        # Extract request lines. Note that the second index is excluded, according to the doc
        line_index = 1
        include_data = []
        File.open(line.include_file_path, 'r') do |fd|
          while line_data = fd.gets
            if (line_index >= include_file_lines[0]) && (include_file_lines[1].nil? || (line_index < include_file_lines[1]))
              include_data << line_data.chomp
            end
            line_index += 1
          end
        end

      when 'src', 'example', 'quote'
        # Prepare tags
        begin_tag = format('#+BEGIN_%s', line.include_file_options[0].upcase)
        if (line.include_file_options[0] == 'src') && !line.include_file_options[1].nil?
          begin_tag += ' ' + line.include_file_options[1]
        end
        end_tag = format('#+END_%s', line.include_file_options[0].upcase)

        # Get lines. Will be transformed into an array at processing
        include_data = format("%s\n%s\n%s", begin_tag, IO.read(line.include_file_path), end_tag)

      else
        include_data = []
      end
      # @todo: support ":minlevel"

      include_data
    end

    def set_name_for_code_block(previous_line, line)
      previous_line.in_buffer_setting? do |key, value|
        line.properties['block_name'] = value if key.downcase == 'name'
      end
    end

    def set_mode_for_results_block_contents(previous_line, line)
      if previous_line.start_of_results_code_block? \
        || (previous_line.assigned_paragraph_type == :comment)
        unless @next_results_block_should_be_exported || (line.paragraph_type == :blank)
          line.assigned_paragraph_type = :comment
        end
      end
    end

    # Creates a new parser from the data in a given file
    def self.load(fname, _opts = {})
      lines = IO.readlines(fname)
      new(lines, opts = {})
    end

    # Saves the loaded orgmode file as a textile file.
    def to_textile
      output = StringIO.new
      output_buffer = TextileOutputBuffer.new(output, document)

      translate(@header_lines, output_buffer)
      document.headlines.each do |headline|
        translate(headline.body_lines, output_buffer)
      end
      output_buffer.output_footnotes!
      output.string
    end

    # Exports the Org mode content into Markdown format
    def to_markdown
      mark_trees_for_export
      export_options = {
        markup_file: @parser_options[:markup_file]
      }
      output = StringIO.new
      output_buffer = MarkdownOutputBuffer.new(output, export_options)

      translate(@header_lines, output_buffer)
      document.headlines.each do |headline|
        translate(headline.body, output_buffer)
      end
      output_buffer.output_footnotes!
      output.string
    end

    # Converts the loaded org-mode file to HTML.
    def to_html
      mark_trees_for_export
      export_options = {
        decorate_title: buffer_settings.fetch('TITLE', nil),
        export_footnotes: export_footnotes?,
        export_heading_number: export_heading_number?,
        export_todo: export_todo?,
        footnotes_title: @parser_options[:footnotes_title],
        generate_heading_id: @parser_options[:generate_heading_id],
        link_abbrevs: document.link_abbreviations,
        ltr: left_to_right?,
        markup_file: @parser_options[:markup_file],
        skip_syntax_highlight: @parser_options[:skip_syntax_highlight],
        use_sub_superscripts: use_sub_superscripts?
      }
      export_options[:skip_tables] = !export_tables?
      output = StringIO.new
      output_buffer = HtmlOutputBuffer.new(output, document, export_options)

      output_buffer.wrap_html(@parser_options[:wrap_html])

      if document.buffer_settings.fetch('TITLE', nil)
        # If we're given a new title, then just create a new line
        # for that title.
        title_line = Line.new(document.title, self, :title)
        translate([title_line], output_buffer)
      end
      translate(@header_lines, output_buffer) unless skip_header_lines?

      # If we've output anything at all, remove the :decorate_title option.
      export_options.delete(:decorate_title) if output.length > 0
      document.headlines.each do |headline|
        translate(headline.body, output_buffer)
      end
      output_buffer.output_footnotes!
      output_buffer.close(@parser_options[:wrap_html])

      return output.string if @parser_options[:skip_rubypants_pass]

      rp = RubyPants.new(output.string)
      rp.to_html
    end

    protected

    attr_reader :document

    private

    def parse_options(options)
      @parser_options = options
      if @parser_options[:allow_include_files].nil?
        if (ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] == 'true') ||
           !ENV['ORG_RUBY_INCLUDE_ROOT'].nil?
          @parser_options[:allow_include_files] = true
        end
      end
      @parser_options[:offset] ||= 0
    end

    # Converts an array of lines to the appropriate format.
    # Writes the output to +output_buffer+.
    def translate(lines, output_buffer)
      output_buffer.output_type = :start
      lines.each { |line| output_buffer.insert(line) }
      output_buffer.flush!
      output_buffer.pop_mode while output_buffer.current_mode
      output_buffer.output
    end

    # Uses export_select_tags and export_exclude_tags to determine
    # which parts of the org-file to export.
    def mark_trees_for_export
      marked_any = false
      # cache the tags
      select = export_select_tags
      exclude = export_exclude_tags
      inherit_export_level = nil
      ancestor_stack = []

      # First pass: See if any headlines are explicitly selected
      document.headlines.each do |headline|
        ancestor_stack.pop while !ancestor_stack.empty? &&
                                 (headline.level <= ancestor_stack.last.level)
        if inherit_export_level && (headline.level > inherit_export_level)
          headline.export_state = :all
        else
          inherit_export_level = nil
          headline.tags.each do |tag|
            next unless select.include? tag

            marked_any = true
            headline.export_state = :all
            ancestor_stack.each { |a| a.export_state = :headline_only unless a.export_state == :all }
            inherit_export_level = headline.level
          end
        end
        ancestor_stack.push headline
      end

      # If nothing was selected, then EVERYTHING is selected.
      document.headlines.each { |h| h.export_state = :all } unless marked_any

      # Second pass. Look for things that should be excluded, and get rid of them.
      document.headlines.each do |headline|
        if inherit_export_level && (headline.level > inherit_export_level)
          headline.export_state = :exclude
        else
          inherit_export_level = nil
          headline.tags.each do |tag|
            if exclude.include? tag
              headline.export_state = :exclude
              inherit_export_level = headline.level
            end
          end
          if headline.comment_headline?
            headline.export_state = :exclude
            inherit_export_level = headline.level
          end
        end
      end
    end
  end
end
