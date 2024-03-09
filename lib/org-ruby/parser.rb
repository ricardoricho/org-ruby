require 'rubypants'

module Orgmode

  ##
  ##  Simple routines for loading / saving an ORG file.
  ##

  class Parser

    # All of the lines of the orgmode file
    attr_reader :lines

    # All of the headlines in the org file
    attr_reader :headlines

    # These are any lines before the first headline
    attr_reader :header_lines

    # This contains any in-buffer settings from the org-mode file.
    # See http://orgmode.org/manual/In_002dbuffer-settings.html#In_002dbuffer-settings
    attr_reader :in_buffer_settings

    # This contains in-buffer options; a special case of in-buffer settings.
    attr_reader :options

    # Array of custom keywords.
    attr_reader :custom_keywords

    # Regexp that recognizes words in custom_keywords.
    def custom_keyword_regexp
      return nil if @custom_keywords.empty?

      Regexp.new("^(#{@custom_keywords.join('|')})\$")
    end

    # A set of tags that, if present on any headlines in the org-file, means
    # only those headings will get exported.
    def export_select_tags
      return Array.new unless @in_buffer_settings["EXPORT_SELECT_TAGS"]

      @in_buffer_settings["EXPORT_SELECT_TAGS"].split
    end

    # A set of tags that, if present on any headlines in the org-file, means
    # that subtree will not get exported.
    def export_exclude_tags
      return Array.new unless @in_buffer_settings["EXPORT_EXCLUDE_TAGS"]

      @in_buffer_settings["EXPORT_EXCLUDE_TAGS"].split
    end

    # Returns true if we are to export todo keywords on headings.
    def export_todo?
      "t" == @options["todo"]
    end

    # Returns true if we are to export footnotes
    def export_footnotes?
      "t" == @options["f"]
    end

    # Returns true if we are to export heading numbers.
    def export_heading_number?
      "t" == @options["num"]
    end

    # Should we skip exporting text before the first heading?
    def skip_header_lines?
      "t" == @options["skip"]
    end

    # Should we export tables? Defaults to true, must be overridden
    # with an explicit "nil"
    def export_tables?
      "nil" != @options["|"]
    end

    # Should we export sub/superscripts? (_{foo}/^{foo})
    # only {} mode is currently supported.
    def use_sub_superscripts?
      @options["^"] != "nil"
    end

    # Support for left to right when buffer or parser option.
    def left_to_right?
      @options["ltr"] == 't' || @parser_options[:ltr]
    end

    def initialize_lines(lines)
      return lines if lines.is_a? Array
      return lines.split("\n") if lines.is_a? String

      raise "Unsupported type for +lines+: #{lines.class}"
    end

    # I can construct a parser object either with an array of lines
    # or with a single string that I will split along \n boundaries.
    def initialize(lines, parser_options = {})
      @lines = initialize_lines lines
      @custom_keywords = []
      @headlines = []
      @current_headline = nil
      @header_lines = []
      @in_buffer_settings = {}
      @options = {}
      @link_abbrevs = {}
      @parser_options = parser_options

      #
      # Include file feature disabled by default since
      # it would be dangerous in some environments
      #
      # http://orgmode.org/manual/Include-files.html
      #
      # It will be activated by one of the following:
      #
      # - setting an ORG_RUBY_ENABLE_INCLUDE_FILES env variable to 'true'
      # - setting an ORG_RUBY_INCLUDE_ROOT env variable with the root path
      # - explicitly enabling it by passing it as an option:
      #   e.g. Orgmode::Parser.new(org_text, { :allow_include_files => true })
      #
      # IMPORTANT: To avoid the feature altogether, it can be _explicitly disabled_ as follows:
      #   e.g. Orgmode::Parser.new(org_text, { :allow_include_files => false })
      #
      if @parser_options[:allow_include_files].nil?
        if (ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] == 'true') \
          || !ENV['ORG_RUBY_INCLUDE_ROOT'].nil?
          @parser_options[:allow_include_files] = true
        end
      end

      @parser_options[:offset] ||= 0

      parse_lines @lines
    end

    # Check include file availability and permissions
    def check_include_file(file_path)
      can_be_included = File.exist? file_path

      unless ENV['ORG_RUBY_INCLUDE_ROOT'].nil?
        # Ensure we have full paths
        root_path = File.expand_path ENV['ORG_RUBY_INCLUDE_ROOT']
        file_path = File.expand_path file_path

        # Check if file is in the defined root path and really exists
        can_be_included = false if file_path.slice(0, root_path.length) != root_path
      end

      can_be_included
    end

    def parse_lines(lines)
      mode = :normal
      previous_line = nil
      table_header_set = false
      lines.each do |text|
        line = Line.new text, self

        if @parser_options[:allow_include_files] && line.include_file? &&
           !line.include_file_path.nil?
            next unless check_include_file line.include_file_path
            include_file(line)
        end

        # Store link abbreviations
        if line.link_abbrev?
          link_abbrev_data = line.link_abbrev_data
          @link_abbrevs[link_abbrev_data[0]] = link_abbrev_data[1]
        end

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
          @headlines << @current_headline = line if line.headline?
          # If there is a setting on this line, remember it.
          line.in_buffer_setting? do |key, value|
            store_in_buffer_setting key.upcase, value
          end

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
      output = ''
      output_buffer = TextileOutputBuffer.new(output)

      translate(@header_lines, output_buffer)
      @headlines.each do |headline|
        translate(headline.body_lines, output_buffer)
      end
      output
    end

    # Exports the Org mode content into Markdown format
    def to_markdown
      mark_trees_for_export
      export_options = {
        markup_file: @parser_options[:markup_file]
      }
      output = ''
      output_buffer = MarkdownOutputBuffer.new(output, export_options)

      translate(@header_lines, output_buffer)
      translate_headlines(@headlines, output_buffer)
      output
    end

    # Converts the loaded org-mode file to HTML.
    def to_html
      mark_trees_for_export
      export_options = {
        decorate_title: in_buffer_settings['TITLE'],
        export_heading_number: export_heading_number?,
        export_todo: export_todo?,
        use_sub_superscripts: use_sub_superscripts?,
        export_footnotes: export_footnotes?,
        link_abbrevs: @link_abbrevs,
        skip_syntax_highlight: @parser_options[:skip_syntax_highlight],
        markup_file: @parser_options[:markup_file],
        footnotes_title: @parser_options[:footnotes_title],
        ltr: left_to_right?,
        generate_heading_id: @parser_options[:generate_heading_id]
      }
      export_options[:skip_tables] = true unless export_tables?
      output = ''
      output_buffer = HtmlOutputBuffer.new(output, export_options)

      if title?
        # If we're given a new title, then just create a new line
        # for that title.
        title_line = Line.new(title, self, :title)
        translate([title_line], output_buffer)
      end
      translate(@header_lines, output_buffer) unless skip_header_lines?

      # If we've output anything at all, remove the :decorate_title option.
      export_options.delete(:decorate_title) if output.length > 0
      translate_headlines(@headlines, output_buffer)
      output << "\n"

      return output if @parser_options[:skip_rubypants_pass]

      rp = RubyPants.new(output)
      rp.to_html
    end

    def title?
      !in_buffer_settings['TITLE'].nil?
    end

    def title
      in_buffer_settings['TITLE']
    end

    ######################################################################
    private

    def translate_headlines(headlines, output_buffer)
      headlines.each do |headline|
        case headline.export_state
        when :headline_only
          translate(headline.body_lines[0, 1], output_buffer)
        when :all
          translate(headline.body_lines, output_buffer)
        end
      end
    end

    # Converts an array of lines to the appropriate format.
    # Writes the output to +output_buffer+.
    def translate(lines, output_buffer)
      output_buffer.output_type = :start
      lines.each { |line| output_buffer.insert(line) }
      output_buffer.flush!
      output_buffer.pop_mode while output_buffer.current_mode
      output_buffer.output_footnotes!
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
      @headlines.each do |headline|
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
      @headlines.each { |h| h.export_state = :all } unless marked_any

      # Second pass. Look for things that should be excluded, and get rid of them.
      @headlines.each do |headline|
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

    # Stores an in-buffer setting.
    def store_in_buffer_setting(key, value)
      if key == 'OPTIONS'

        # Options are stored in a hash. Special-case.
        value.scan(/([^ ]*):((((\(.*\))))|([^ ])*)/) do |o, v|
          @options[o] = v
        end
      elsif key =~ /^(TODO|SEQ_TODO|TYP_TODO)$/
        # Handle todo keywords specially.
        value.split.each do |keyword|
          keyword.gsub!(/\(.*\)/, '') # Get rid of any parenthetical notes
          keyword = Regexp.escape(keyword)
          next if keyword == '\\|' # Special character in the todo format, not really a keyword

          @custom_keywords << keyword
        end
      else
        in_buffer_settings[key] = value
      end
    end
  end                             # class Parser
end                               # module Orgmode
