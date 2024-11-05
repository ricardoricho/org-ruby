module Orgmode

  class MarkdownOutputBuffer < OutputBuffer

    def initialize(output, opts = {})
      super(output)
      @options = opts
      @custom_blocktags = {} if @options[:markup_file]

      if @options[:markup_file]
        do_custom_markup
      end
    end

    def push_mode(mode, indent, properties={})
      super(mode, indent, properties)
    end

    def pop_mode
      m = super
      @list_indent_stack.pop
      m
    end

    # Maps org markup to markdown markup.
    MarkdownMap = {
      "*" => "**",
      "/" => "*",
      "_" => "*",
      "=" => "`",
      "~" => "`",
      "+" => "~~"
    }

    # Handles inline formatting for markdown.
    def inline_formatting(input)
      @re_help.rewrite_emphasis(input) do |marker, body|
        m = MarkdownMap[marker]
        "#{m}#{body}#{m}"
      end
      @re_help.rewrite_subp(input) do |base, type, text|
        case type
        when '_'
          "#{base}<sub>#{text}</sub>"
        when '^'
          "#{base}<sup>#{text}</sup>"
        end
      end
      @re_help.rewrite_links input do |link, defi|
        # We don't add a description for images in links, because its
        # empty value forces the image to be inlined.
        defi ||= link unless link =~ @re_help.org_image_file_regexp
        link = link.gsub(/ /, "%%20")

        if defi =~ @re_help.org_image_file_regexp
          "![#{defi}](#{defi})"
        elsif defi
          "[#{defi}](#{link})"
        else
          "[#{link}](#{link})"
        end
      end

      # Just reuse Textile special symbols for now?
      Orgmode.special_symbols_to_textile(input)
      input = @re_help.restore_code_snippets input
      input
    end

    # Flushes the current buffer
    def flush!
      return false if @buffer.string.empty? && @output_type != :blank

      @buffer.string = @buffer.string.gsub!(/\A\n*/, "")

      case
      when mode_is_code?(current_mode)
        @output.write("```#{@block_lang}\n", @buffer.string, "\n", "```\n")
      when preserve_whitespace?
        @output.write(@buffer.string, "\n")
      when @output_type == :blank
        @output.write("\n")
      else
        case current_mode
        when :paragraph
          @output.write "> " if @mode_stack[0] == :quote
        when :list_item
          @output.write(" " * @mode_stack.count(:list_item), "* ")
        when :horizontal_rule
          @output.write "---"
        end
        @output.write(inline_formatting(@buffer.string), "\n")
      end
      @buffer = StringIO.new
    end

    def add_line_attributes headline
      @output.write("#" * headline.level, " ")
    end
  end
end
