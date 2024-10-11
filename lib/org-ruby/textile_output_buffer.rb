module Orgmode
  class TextileOutputBuffer < OutputBuffer

    def initialize(output, document = nil)
      super(output, document)
      @add_paragraph = true
      @support_definition_list = true # TODO this should be an option
    end

    def push_mode(mode, indent, properties={})
      super(mode, indent, properties)
      @output << "bc. " if mode_is_code? mode
      if mode == :center || mode == :quote
        @add_paragraph = false
        @output << "\n"
      end
    end

    def pop_mode
      m = super
      @list_indent_stack.pop
      if m == :center || m == :quote
        @add_paragraph = true
        @output << "\n"
      end
      m
    end

    # Maps org markup to textile markup.
    TextileMap = {
      "*" => "*",
      "/" => "_",
      "_" => "_",
      "=" => "@",
      "~" => "@",
      "+" => "+"
    }

    # Handles inline formatting for textile.
    def inline_formatting(input)
      @re_help.rewrite_emphasis input do |marker, body|
        m = TextileMap[marker]
        "#{m}#{body}#{m}"
      end

      @re_help.rewrite_subp input do |type, text|
        if type == "_"
          "~#{text}~"
        elsif type == "^"
          "^#{text}^"
        end
      end

      @re_help.rewrite_links input do |link, defi|
        [link, defi].compact.each do |text|
          # We don't support search links right now. Get rid of it.
          text.sub!(/\A(file:[^\s]+)::[^\s]*?\Z/, "\\1")
          text.sub!(/\A(file:[^\s]+)\.org\Z/i, "\\1.textile")
          text.sub!(/\Afile:(?=[^\s]+\Z)/, "")
        end

        # We don't add a description for images in links, because its
        # empty value forces the image to be inlined.
        defi ||= link unless link =~ @re_help.org_image_file_regexp
        link = link.gsub(/ /, "%%20")

        if defi =~ @re_help.org_image_file_regexp
          defi = "!#{defi}(#{defi})!"
        elsif defi
          defi = "\"#{defi}\""
        end

        if defi
          "#{defi}:#{link}"
        else
          "!#{link}(#{link})!"
        end
      end

      @re_help.capture_footnote_definition(input) do |_label, _content|
        # Capture definition and replace it with nil
        nil
      end

      @re_help.rewrite_footnote(input) do |label, content|
        # textile only support numerical names, so we need to do some conversion
        # Try to find the footnote and use its index
        footnote = document.footnotes.find do |footnote|
          footnote[:label] == label || footnote[:content] == content
        end

        "[#{footnote[:index]}]"
      end

      Orgmode.special_symbols_to_textile(input)
      input = @re_help.restore_code_snippets input
      input
    end

    def output_footnotes!
      return if document.footnotes.empty?

      document.footnotes.each do |footnote|
        @output << "\nfn#{footnote[:index]}. #{footnote[:content].lstrip || 'DEFINITION NOT FOUND' }\n"
      end
    end

    # Flushes the current buffer
    def flush!
      return false if @buffer.empty? and @output_type != :blank
      @logger.debug "FLUSH ==========> #{@output_type}"
      @buffer.gsub!(/\A\n*/, "")

      case
      when preserve_whitespace?
        @output << @buffer << "\n"

      when @output_type == :blank
        @output << "\n"

      else
        case current_mode
        when :paragraph
          @output << "p. " if @add_paragraph
          @output << "p=. " if @mode_stack[0] == :center
          @output << "bq. " if @mode_stack[0] == :quote

        when :list_item
          if @mode_stack[-2] == :ordered_list
            @output << "#" * @mode_stack.count(:list_item) << " "
          else # corresponds to unordered list
            @output << "*" * @mode_stack.count(:list_item) << " "
          end

        when :definition_term
          if @support_definition_list
            @output << "-" * @mode_stack.count(:definition_term) << " "
            @buffer.sub!("::", ":=")
          end
        end
        @output << inline_formatting(@buffer) << "\n"
      end
      @buffer = ""
    end

    def add_line_attributes headline
      @output << "h#{headline.level}. "
    end
  end
end
