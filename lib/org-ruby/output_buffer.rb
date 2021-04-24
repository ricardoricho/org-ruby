require 'logger'

module Orgmode

  # The OutputBuffer is used to accumulate multiple lines of orgmode
  # text, and then emit them to the output all in one go. The class
  # will do the final textile substitution for inline formatting and
  # add a newline character prior emitting the output.
  class OutputBuffer

    # This is the overall output buffer
    attr_reader :output, :mode_stack, :list_indent_stack

    # This is the current type of output being accumulated.
    attr_accessor :output_type, :headline_number_stack

    # Creates a new OutputBuffer object that is bound to an output object.
    # The output will get flushed to =output=.
    def initialize(output)
      # This is the accumulation buffer. It's a holding pen so
      # consecutive lines of the right type can get stuck together
      # without intervening newlines.
      @buffer = ""

      # This stack is used to do proper outline numbering of
      # headlines.
      @headline_number_stack = []

      @output = output
      @output_type = :start
      @list_indent_stack = []
      @mode_stack = []

      # regexp module
      @re_help = RegexpHelper.new
      @logger = Logger.new(STDERR)
      if ENV['DEBUG'] || $DEBUG
        @logger.level = Logger::DEBUG
      else
        @logger.level = Logger::WARN
      end
    end

    def current_mode
      mode_stack.last
    end

    def push_mode(mode, indent, properties={})
      mode_stack.push(mode)
      # Here seem that inherit buffers do their magic.
      list_indent_stack.push(indent)
    end

    def pop_mode(mode=nil)
      mode_stack.pop
    end

    def insert(line)
      # Prepares the output buffer to receive content from a line.
      # As a side effect, this may flush the current accumulated text.
      @logger.debug "Looking at #{line.paragraph_type}|#{line.assigned_paragraph_type}(#{current_mode}) : #{line.to_s}"

      # We try to get the lang from #+BEGIN_SRC blocks
      @block_lang = line.block_lang if line.begin_block?
      unless should_accumulate_output?(line)
        flush!
        maintain_mode_stack(line)
      end

      @buffer.concat(line_get_content(line))
      html_buffer_code_block_indent(line)
      @output_type = line.assigned_paragraph_type || line.paragraph_type
    end
    # Insert line Helpers

    # This is a line method
    def line_get_content(line)
      # Adds the current line to the output buffer
      case
      when line.assigned_paragraph_type == :comment
        # Don't add to buffer
        ""
      when line.title?
        line.output_text
      when line.raw_text?
        # This case is for html buffer, because buffer_tag is a method
        if line.raw_text_tag == buffer_tag
          "\n#{line.output_text}"
        else
          ""
        end
      when preserve_whitespace?
        if line.block_type
          ""
        else
          "\n#{line.output_text}"
        end
      when line.assigned_paragraph_type == :code
        # If the line is contained within a code block but we should
        # not preserve whitespaces, then we do nothing.
        ""
      when line.is_a?(Headline)
        add_line_attributes(line)
        "\n#{line.output_text.strip}"

      when ([:definition_term, :list_item, :table_row, :table_header,
             :horizontal_rule].include? line.paragraph_type)

        "\n#{line.output_text.strip}"
      when line.paragraph_type == :paragraph
        "\n""#{buffer_indentation}#{line.output_text.strip}"
      else ""
      end
    end

    def html_buffer_code_block_indent(line)
      # this is implemented in html output buffer only
    end
    # Insert helpers end here.

    # Gets the next headline number for a given level. The intent is
    # this function is called sequentially for each headline that
    # needs to get numbered. It does standard outline numbering.
    def get_next_headline_number(level)
      raise "Headline level not valid: #{level}" if level <= 0

      while level > @headline_number_stack.length do
        @headline_number_stack.push 0
      end
      while level < @headline_number_stack.length do
        @headline_number_stack.pop
      end
      @headline_number_stack[level - 1] += 1
      @headline_number_stack.join(".")
    end

    # Gets the current list indent level.
    def list_indent_level
      @list_indent_stack.length
    end

    # Test if we're in an output mode in which whitespace is significant.
    def preserve_whitespace?
      [:example, :inline_example, :raw_text, :src].include? current_mode
    end

    def do_custom_markup
      if File.exists? @options[:markup_file]
        load_custom_markup
        if @custom_blocktags.empty?
          no_valid_markup_found
        else
          set_custom_markup
        end
      else
        no_custom_markup_file_exists
      end
    end

    def load_custom_markup
      require 'yaml'
      self.class.to_s == 'Orgmode::MarkdownOutputBuffer' ? filter = '^MarkdownMap$' : filter = '^HtmlBlockTag$|^Tags$'
      @custom_blocktags = YAML.load_file(@options[:markup_file]).select {|k| k.to_s.match(filter) }
    end

    def set_custom_markup
      @custom_blocktags.keys.each do |k|
        @custom_blocktags[k].each {|key,v| self.class.const_get(k.to_s)[key] = v if self.class.const_get(k.to_s).key? key}
      end
    end

    def no_valid_markup_found
      self.class.to_s == 'Orgmode::MarkdownOutputBuffer' ? tags = 'MarkdownMap' : tags = 'HtmlBlockTag or Tags'
      @logger.debug "Setting Custom Markup failed. No #{tags} key where found in: #{@options[:markup_file]}."
      @logger.debug "Continuing export with default markup."
    end

    def no_custom_markup_file_exists
      @logger.debug "Setting Custom Markup failed. No such file exists: #{@options[:markup_file]}."
      @logger.debug "Continuing export with default tags."
    end

    protected

    attr_reader :block_lang, :list_indent_stack

    def indentation_level
      list_indent_stack.length - 1
    end

    # Implemented only in HtmlOutputBuffer
    def buffer_tag
      # raise NoImplementedError 'implemnt this in your output buffer'
      nil
    end

    private

    def mode_is_heading?(mode)
      [:heading1, :heading2, :heading3,
       :heading4, :heading5, :heading6].include? mode
    end

    def mode_is_block?(mode)
      [:quote, :center, :example, :src].include? mode
    end

    def mode_is_code?(mode)
      [:example, :src].include? mode
    end

    def boundary_of_block?(line)
      # Boundary of inline example
      ((line.paragraph_type == :inline_example) ^ (@output_type == :inline_example)) ||
        # Boundary of begin...end block
        mode_is_block?(@output_type)
    end

    def maintain_mode_stack(line)
      # Always close the following lines
      pop_mode if (mode_is_heading?(current_mode) ||
                   current_mode == :paragraph ||
                   current_mode == :horizontal_rule ||
                   current_mode == :inline_example ||
                   current_mode == :raw_text)

      # End-block line closes every mode within block
      if line.end_block? and @mode_stack.include? line.paragraph_type
        pop_mode until current_mode == line.paragraph_type
      end

      if ((not line.paragraph_type == :blank) or
          @output_type == :blank)
        # Close previous tags on demand. Two blank lines close all tags.
        while ((not @list_indent_stack.empty?) and
               @list_indent_stack.last >= line.indent and
               # Don't allow an arbitrary line to close block
               (not mode_is_block? current_mode))
          # Item can't close its major mode
          if (@list_indent_stack.last == line.indent and
              line.major_mode == current_mode)
            break
          else
            pop_mode
          end
        end
      end

      # Special case: Only end-block line closes block
      pop_mode if line.end_block? and line.paragraph_type == current_mode

      unless line.paragraph_type == :blank or line.assigned_paragraph_type == :comment
        if (@list_indent_stack.empty? or
            @list_indent_stack.last <= line.indent or
            mode_is_block? current_mode)
          # Opens the major mode of line if it exists
          if @list_indent_stack.last != line.indent or mode_is_block? current_mode
            push_mode(line.major_mode, line.indent, line.properties) if line.major_mode
          end
          # Opens tag that precedes text immediately
          push_mode(line.paragraph_type, line.indent,
                    line.properties) unless line.end_block?
        end
      end
    end

    def add_line_attributes(headline)
      # Implemented by specific output buffers
    end

    def output_footnotes!
      return false
    end

    # Tests if the current line should be accumulated in the current
    # output buffer.
    def should_accumulate_output? line
      # Special case: Assign mode if not yet done.
      return false unless current_mode

      # Special case: Handles accumulating block content and example lines
      if mode_is_code? current_mode
        return true unless (line.end_block? &&
                            line.paragraph_type == current_mode)
      end
      return false if boundary_of_block? line
      return true if current_mode == :inline_example

      # Special case: Don't accumulate the following lines.
      return false if (mode_is_heading? @output_type or
                       @output_type == :comment or
                       @output_type == :horizontal_rule or
                       @output_type == :raw_text)

      # Special case: Blank line at least splits paragraphs
      return false if @output_type == :blank

      if line.paragraph_type == :paragraph
        # Paragraph gets accumulated only if its indent level is
        # greater than the indent level of the previous mode.
        if @mode_stack[-2] and not mode_is_block? @mode_stack[-2]
          return false if line.indent <= @list_indent_stack[-2]
        end
        # Special case: Multiple "paragraphs" get accumulated.
        return true
      end

      false
    end

    def buffer_indentation
      ""
    end

    def flush!; false; end
    def output_footnotes!; false; end
  end                           # class OutputBuffer
end                             # module Orgmode
