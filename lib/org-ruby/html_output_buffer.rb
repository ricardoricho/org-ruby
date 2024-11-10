module Orgmode
  class HtmlOutputBuffer < OutputBuffer
    HtmlBlockTag = {
      :paragraph        => "p",
      :ordered_list     => "ol",
      :unordered_list   => "ul",
      :list_item        => "li",
      :definition_list  => "dl",
      :definition_term  => "dt",
      :definition_descr => "dd",
      :table            => "table",
      :table_row        => "tr",
      :quote            => "blockquote",
      :example          => "pre",
      :src              => "pre",
      :inline_example   => "pre",
      :center           => "div",
      :heading1         => "h1",
      :heading2         => "h2",
      :heading3         => "h3",
      :heading4         => "h4",
      :heading5         => "h5",
      :heading6         => "h6",
      :title            => "h1"
    }

    attr_reader :options

    def initialize(output, document = nil, opts = {})
      super(output, document)
      @options = opts
      @new_paragraph = :start
      @unclosed_tags = []
      @code_block_indent = nil

      do_custom_markup
    end

    def buffer_tag
      'HTML'
    end

    def close_tag(mode)
      closing_tag = HtmlBlockTag[mode]
      strip_tag = closing_tag.split(' ').first
      "</#{strip_tag}>"
    end

    def wrap_html(options = {})
      return if options.nil? || options.empty?

      output.write "<!DOCTYPE html>\n<html>\n  <head>\n    <title>#{document.title}</title>\n#{link_stylesheets(options[:css_files]).join("\n")}\n  </head>\n  <body>\n"
    end

    def link_stylesheets(files = [])
      return [] if files.nil?

      files.map do |file|
        "    <link rel=\"stylesheet\" type=\"text/css\" href=\"#{file}\">"
      end
    end

    def close(close_html)
      if close_html
        output.write "\n  </body>\n</html>\n"
      else
        output.write "\n"
      end
    end

    # Output buffer is entering a new mode. Use this opportunity to
    # write out one of the block tags in the HtmlBlockTag constant to
    # put this information in the HTML stream.
    def push_mode(mode, indent, properties={})
      super(mode, indent, properties)
      return if !html_tags.include?(mode) || skip_css?(mode)

      css_class = get_css_attr(mode)
      push_indentation(@new_paragraph != :start)

      html_tag = HtmlBlockTag[mode]
      # Check to see if we need to restart numbering from a
      # previous interrupted li
      if restart_numbering?(mode, properties)
        list_item_tag = HtmlBlockTag[:list_item]
        start = properties[list_item_tag]
        output.write "<#{html_tag} start=#{start}#{css_class}>"
      else
        output.write "<#{html_tag}#{css_class}>"
      end
      # Entering a new mode obliterates the title decoration
      @options[:decorate_title] = nil
    end

    def restart_numbering?(mode, properties)
      mode_is_ol?(mode) && properties.key?(HtmlBlockTag[:list_item])
    end

    def table?(mode)
      %i[table table_row table_separator table_header].include?(mode)
    end

    def src?(mode)
      %i[src].include?(mode)
    end

    def skip_syntax_highlight?
      !options[:skip_syntax_highlight]
    end

    def push_indentation(condition)
      indent = "  " * indentation_level
      condition && output.write("\n", indent)
      @new_paragraph = true
    end

    def html_tags
      HtmlBlockTag.keys
    end

    def skip_css?(mode)
      (table?(mode) && skip_tables?) ||
        (src?(mode) && skip_syntax_highlight?)
    end

    # We are leaving a mode. Close any tags that were opened when
    # entering this mode.
    def pop_mode
      mode = super
      return list_indent_stack.pop unless html_tags.include?(mode)
      return list_indent_stack.pop if skip_css?(mode)

      push_indentation(@new_paragraph)
      output.write close_tag(mode)
      list_indent_stack.pop
    end

    def highlight(code, lang)
      Highlighter.highlight(code, lang)
    end

    def flush!
      return false if @buffer.string.empty?
      return @buffer = StringIO.new if (mode_is_table?(current_mode) && skip_tables?)

      if preserve_whitespace?
        strip_code_block! if mode_is_code? current_mode

        if (current_mode == :src)
          highlight_html_buffer
        else
          if (current_mode == :html || current_mode == :raw_text)
            remove_new_lines_in_buffer(@new_paragraph == :start)
          else
            @buffer.string = escapeHTML(@buffer.string)
          end
        end

        # Whitespace is significant in :code mode. Always output the
        # buffer and do not do any additional translation.
        output.write(@buffer.string)
      else
        @buffer.string.lstrip!
        @new_paragraph = nil
        if (current_mode == :definition_term)
          d = @buffer.string.split(/\A(.*[ \t]+|)::(|[ \t]+.*?)$/, 4)

          definition = d[1].strip
          if definition.empty?
            output.write "???"
          else
            output.write inline_formatting(definition)
          end
          indent = list_indent_stack.last
          pop_mode

          @new_paragraph = :start
          push_mode(:definition_descr, indent)
          output.write inline_formatting(d[2].strip + d[3])
          @new_paragraph = nil
        elsif (current_mode == :horizontal_rule)

          add_paragraph unless @new_paragraph == :start
          @new_paragraph = true
          output.write "<hr />"

        else
          output.write(inline_formatting(@buffer.string))
        end
      end
      @buffer = StringIO.new
    end

    # Flush! helping methods
    def highlight_html_buffer
      if skip_syntax_hightlight?
        @buffer.string = escapeHTML(@buffer.string)
      else
        lang = normalize_lang @block_lang
        @buffer.string = highlight(@buffer.string, lang)
      end
    end

    def skip_syntax_hightlight?
      current_mode == :src && options[:skip_syntax_highlight]
    end

    def remove_new_lines_in_buffer(condition)
      return unless %i[html raw_text].include?(current_mode)

      condition && @buffer.string.gsub!(/\A\n/, "")
      @new_paragraph = true
    end
    #flush helpers ends here.


    def add_line_attributes(headline)
      level = headline.level
      add_headline_id(headline)

      if options[:export_heading_number]
        headline_level = headline.headline_level
        heading_number = get_next_headline_number(headline_level)
        output.write "<span class=\"heading-number heading-number-#{level}\">#{heading_number}</span> "
      end
      if options[:export_todo] && headline.keyword
        keyword = headline.keyword
        output.write "<span class=\"todo-keyword #{keyword}\">#{keyword}</span> "
      end
    end

    def add_headline_id(line)
      return unless options[:generate_heading_id]
      # Nice hack to "open" the line tag and include the id
      output.pos = output.pos - 1
      output.write ' id="', line.slugify, '">'
    end

    def html_buffer_code_block_indent(line)
      if mode_is_code?(current_mode) && !line.block_type
        # Determines the amount of whitespaces to be stripped at the
        # beginning of each line in code block.
        if line.paragraph_type != :blank
          if @code_block_indent
            @code_block_indent = [@code_block_indent, line.indent].min
          else
            @code_block_indent = line.indent
          end
        end
      end
    end


    # Only footnotes defined in the footnote (i.e., [fn:0:this is the footnote definition])
    # will be automatically
    # added to a separate Footnotes section at the end of the document. All footnotes that are
    # defined separately from their references will be rendered where they appear in the original
    # Org document.
    def output_footnotes!
      return if !options[:export_footnotes] || document.footnotes.empty?

      output.write footnotes_header
      document.footnotes.each do |footnote|
        @buffer.string = footnote[:content].empty? && footnote[:label] || footnote[:content]
        a_href = footnote[:index]
        output.write "<div class=\"footdef\"><sup><a id=\"fn.#{a_href}\" class=\"footnum\" ",
                     "href=\"#fnr.#{a_href}\" role=\"doc-backlink\">#{a_href}</a></sup>",
                     "<div class=\"footpara\" role=\"doc-footnote\"><p class=\"footpara\">",
                     inline_formatting(@buffer.string),
                     "</p></div></div>\n"
      end

      output.write "</div>\n</div>"
    end

    def footnotes_header
      footnotes_title = options[:footnotes_title] || "Footnotes:"
      "\n<div id=\"footnotes\">\n<h2 class=\"footnotes\">#{footnotes_title}</h2>\n<div id=\"text-footnotes\">\n"
    end

    # Test if we're in an output mode in which whitespace is significant.
    def preserve_whitespace?
      super || current_mode == :html
    end

    def rewrite_sub_superscripts(str)
      @re_help.rewrite_subp(str) do |base, type, text|
        case type
        when '_'
          base + quote_tags("<sub>") + text + quote_tags("</sub>")
        when '^'
          base + quote_tags("<sup>") + text + quote_tags("</sup>")
        end
      end
    end

    private

    def get_css_attr(mode)
      case
      when (mode == :src and block_lang.empty?)
        " class=\"src\""
      when (mode == :src and not block_lang.empty?)
        " class=\"src\" lang=\"#{block_lang}\""
      when (mode == :example || mode == :inline_example)
        " class=\"example\""
      when mode == :center
        " style=\"text-align: center\""
      when options[:decorate_title]
        " class=\"title\""
      when options[:ltr]
        " dir=\"auto\""
      end
    end

    def skip_tables?
      options[:skip_tables]
    end

    def mode_is_table?(mode)
      (mode == :table or mode == :table_row or
       mode == :table_separator or mode == :table_header)
    end

    def mode_is_ol?(mode)
      mode == :ordered_list
    end

    # Escapes any HTML content in string
    def escape_string!(str)
      str.gsub!(/&/, "&amp;")
      # Escapes the left and right angular brackets but construction
      # @@html:<text>@@ which is formatted to <text>
      str.gsub!(/<([^<>\n]*)/) do |match|
        ($`[-7..-1] == "@@html:" && $'[0..2] == ">@@") ? $& : "&lt;#{$1}"
      end
      str.gsub!(/([^<>\n]*)>/) do |match|
        $`[-8..-1] == "@@html:<" ? $& : "#{$1}&gt;"
      end
      str.gsub!(/@@html:(<[^<>\n]*>)@@/, "\\1")
      Orgmode.special_symbols_to_html(str)
    end

    def quote_tags(str)
      str.gsub(/(<[^<>\n]*>)/, "@@html:\\1@@")
    end

    def buffer_indentation
      "  " * list_indent_stack.length
    end

    def add_paragraph
      indent = "  " * (list_indent_stack.length - 1)
      output.write("\n", indent)
    end

    Tags = {
      "*" => { :open => "b", :close => "b" },
      "/" => { :open => "i", :close => "i" },
      "_" => { :open => "span style=\"text-decoration:underline;\"",
               :close => "span" },
      "=" => { :open => "code", :close => "code" },
      "~" => { :open => "code", :close => "code" },
      "+" => { :open => "del", :close => "del" }
    }

    # Applies inline formatting rules to a string.
    def inline_formatting(str)
      rewrite_emphasis(str)
      rewrite_targets(str)

      rewrite_sub_superscripts(str) if options[:use_sub_superscripts]
      rewrite_links(str)
      rewrite_row(str) if @output_type == :table_row
      rewrite_table_header(str) if @output_type == :table_header
      rewrite_footnote(str) if options[:export_footnotes]

      # Two backslashes \\ at the end of the line make a line break without breaking paragraph.
      if @output_type != :table_row && @output_type != :table_header
        str.sub!(/\\\\$/, quote_tags("<br />"))
      end
      str = escape_string!(str)
      str = @re_help.restore_code_snippets(str)
    end

    def rewrite_emphasis(str)
      @re_help.rewrite_emphasis(str) do |marker, text|
        if marker == "=" || marker == "~"
          escaped_text = escapeHTML(text)
          "<#{Tags[marker][:open]}>#{escaped_text}</#{Tags[marker][:close]}>"
        else
          quote_tags("<#{Tags[marker][:open]}>") + text +
            quote_tags("</#{Tags[marker][:close]}>")
        end
      end
    end

    def rewrite_table_header(str)
      str.gsub!(/^\|\s*/, quote_tags("<th>"))
      str.gsub!(/\s*\|$/, quote_tags("</th>"))
      str.gsub!(/\s*\|\s*/, quote_tags("</th><th>"))
    end

    def rewrite_row(str)
      str.gsub!(/^\|\s*/, quote_tags("<td>"))
      str.gsub!(/\s*\|$/, quote_tags("</td>"))
      str.gsub!(/\s*\|\s*/, quote_tags("</td><td>"))
    end

    def rewrite_footnote(str)
      @re_help.capture_footnote_definition(str) { nil }
      @re_help.rewrite_footnote(str) do |label, content|
        footnote = document.footnotes.find do |footnote|
          footnote[:label] == label || footnote[:content] == content
        end

        a_id = (footnote[:label].nil? || footnote[:label].empty?) ? footnote[:index] : footnote[:label]
        a_text = footnote[:index]
        a_href = (footnote[:label].nil? || footnote[:label].empty?) ? footnote[:index] : footnote[:label]

        footnote_tag = "<sup><a id=\"fnr.#{a_id}\" class=\"footref\" href=\"#fn.#{a_href}\" role=\"doc-backlink\">#{a_text}</a></sup>"
        quote_tags(footnote_tag)
      end
    end

    def rewrite_links(str)
      @re_help.rewrite_links(str) do |link, defi|
        [link, defi].compact.each do |text|
          text.sub!(/\A(file:[^\s]+)::[^\s]*?\Z/, "\\1")
          # We don't support search links right now. Get rid of it.
          text.sub!(/\Afile(|\+emacs|\+sys):(?=[^\s]+\Z)/, "")
        end

        # We don't add a description for images in links, because its
        # empty value forces the image to be inlined.
        defi ||= link unless link =~ @re_help.org_image_file_regexp

        if defi =~ @re_help.org_image_file_regexp
          defi = quote_tags "<img src=\"#{defi}\" alt=\"#{defi}\" />"
        end

        if defi
          link = options[:link_abbrevs][link] if options[:link_abbrevs].has_key?(link)
          target = document.targets.find do |target|
            target[:content] == defi
          end
          link = "#tg.#{target[:index]}" if target
          quote_tags("<a href=\"#{link}\">") + defi + quote_tags("</a>")
        else
          quote_tags "<img src=\"#{link}\" alt=\"#{link}\" />"
        end
      end
    end

    def rewrite_targets(line)
      line.gsub!(RegexpHelper.target) do |_match|
        match = Regexp.last_match
        target = document.targets.find do |target|
          target[:content] == match[:content]
        end
        target_tag = "<span id=\"tg.#{target[:index]}\">#{target[:content]}</span>"
        quote_tags(target_tag)
      end
    end

    def normalize_lang(lang)
      case lang
      when 'emacs-lisp', 'common-lisp', 'lisp'
        'scheme'
      when 'ipython'
        'python'
      when 'js2'
        'javascript'
      when ''
        'text'
      else
        lang
      end
    end

    # Helper method taken from Rails
    # https://github.com/rails/rails/blob/c2c8ef57d6f00d1c22743dc43746f95704d67a95/activesupport/lib/active_support/core_ext/kernel/reporting.rb#L10
    def silence_warnings
      warn_level = $VERBOSE
      $VERBOSE = nil
      yield
    ensure
      $VERBOSE = warn_level
    end

    def strip_code_block!
      if @code_block_indent and @code_block_indent > 0
        strip_regexp = Regexp.new("^" + " " * @code_block_indent)
        @buffer.string.gsub!(strip_regexp, "")
      end
      @code_block_indent = nil

      # Strip proctective commas generated by Org mode (C-c ')
      @buffer.string.gsub!(/^(\s*)(,)(\s*)([*]|#\+)/) do |match|
        "#{$1}#{$3}#{$4}"
      end
    end

    private

    # The CGI::escapeHTML function backported from the Ruby standard library
    # as of commit fd2fc885b43283aa3d76820b2dfa9de19a77012f
    #
    # Implementation of the cgi module can change among Ruby versions
    # so stabilizing on a single one here to avoid surprises.
    #
    # https://github.com/ruby/ruby/blob/trunk/lib/cgi/util.rb
    #
    # The set of special characters and their escaped values
    TABLE_FOR_ESCAPE_HTML__ = {
      "'" => '&#39;',
      '&' => '&amp;',
      '"' => '&quot;',
      '<' => '&lt;',
      '>' => '&gt;'
    }.freeze

    # Escape special characters in HTML, namely &\"<>
    #   escapeHTML('Usage: foo "bar" <baz>')
    #      # => "Usage: foo &quot;bar&quot; &lt;baz&gt;"
    def escapeHTML(string)
      string.gsub(/['&"<>]/, TABLE_FOR_ESCAPE_HTML__)
    end
  end
end
