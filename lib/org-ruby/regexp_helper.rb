require 'org-ruby/line_regexp'
require 'org-ruby/headline_regexp'
require 'org-ruby/image_regexp'

module Orgmode

  # = Summary
  #
  # This class contains helper routines to deal with the Regexp "black
  # magic" you need to properly parse org-mode files.
  #
  # = Key methods
  #
  # * Use +rewrite_emphasis+ to replace org-mode emphasis strings (e.g.,
  #   \/italic/) with the suitable markup for the output.
  #
  # * Use +rewrite_links+ to get a chance to rewrite all org-mode
  #   links with suitable markup for the output.
  #
  # * Use +rewrite_images+ to rewrite all inline image links with suitable
  #   markup for the output.
  class RegexpHelper
    extend LineRegexp
    extend HeadlineRegexp
    extend ImageRegexp

    ######################################################################
    # EMPHASIS
    #
    # I figure it's best to stick as closely to the elisp implementation
    # as possible for emphasis. org.el defines the regular expression that
    # is used to apply "emphasis" (in my terminology, inline formatting
    # instead of block formatting). Here's the documentation from org.el.
    #
    # Terminology: In an emphasis string like " *strong word* ", we
    # call the initial space PREMATCH, the final space POSTMATCH, the
    # stars MARKERS, "s" and "d" are BORDER characters and "trong wor"
    # is the body.  The different components in this variable specify
    # what is allowed/forbidden in each part:
    #
    # pre          Chars allowed as prematch.  Line beginning allowed, too.
    # post         Chars allowed as postmatch.  Line end will be allowed too.
    # border       The chars *forbidden* as border characters.
    # body-regexp  A regexp like \".\" to match a body character.  Don't use
    #              non-shy groups here, and don't allow newline here.
    # newline      The maximum number of newlines allowed in an emphasis exp.

    attr_reader :code_snippets # Public for tests, only use in emphasis.

    def initialize
      # Set up the emphasis regular expression.
      @code_snippets = []
    end

    # Finds all emphasis matches in a string.
    # Supply a block that will get the marker and body as parameters.
    def match_all(str, &block)
      if block_given?
        str.scan(org_emphasis_regexp) do |_match|
          yield Regexp.last_match[2], Regexp.last_match[3]
        end
      else
        str.scan(org_emphasis_regexp)
      end
    end

    # Compute replacements for all matching emphasized phrases.
    # Supply a block that will get the marker and body as parameters;
    # return the replacement string from your block.
    #
    # = Example
    #
    #   re = RegexpHelper.new
    #   result = re.rewrite_emphasis("*bold*, /italic/, =code=") do |marker, body|
    #       "<#{map[marker]}>#{body}</#{map[marker]}>"
    #   end
    #
    # In this example, the block body will get called three times:
    #
    # 1. Marker: "*", body: "bold"
    # 2. Marker: "/", body: "italic"
    # 3. Marker: "=", body: "code"
    #
    # The return from this block is a string that will be used to
    # replace "*bold*", "/italic/", and "=code=",
    # respectively. (Clearly this sample string will use HTML-like
    # syntax, assuming +map+ is defined appropriately.)
    def rewrite_emphasis(str, &block)
      # escape the percent signs for safe restoring code snippets
      str.gsub!(/%/, "%%")
      str.gsub!(org_emphasis_regexp) do |_match|
        pre = Regexp.last_match(1)
        # preserve the code snippet from further formatting
        inner = yield Regexp.last_match(2), Regexp.last_match(3)
        if %w[= ~].include?(Regexp.last_match(2))
          # code is not formatted, so turn to single percent signs
          inner.gsub!(/%%/, "%")
          @code_snippets.push inner
          "#{pre}%s"
        else
          "#{pre}#{inner}"
        end
      end
    end

    # rewrite subscript and superscript (_{foo} and ^{bar})
    def rewrite_subp(str)
      str.gsub!(RegexpHelper.subp) do |_match|
        match = Regexp.last_match
        yield match[:base], match[:type], match[:text]
      end
    end

    # rewrite footnotes
    def rewrite_footnote(str)
      str.gsub!(RegexpHelper.footnote_reference) do |_match|
        match = Regexp.last_match
        yield match[:label], match[:contents]
      end
    end

    def capture_footnote_definition(str)
      str.gsub!(RegexpHelper.footnote_definition) do |_match|
        match = Regexp.last_match
        yield match[:label], match[:contents]
      end
    end

    def rewrite_links(str)
      str.gsub!(RegexpHelper.org_link) do |_match|
        yield Regexp.last_match['url'], Regexp.last_match['friendly_text']
      end
      str.gsub!(org_angle_link_text_regexp) do |_match|
        yield Regexp.last_match(1), nil
      end
    end

    def restore_code_snippets(str)
      # Replace all %s strings with the accumulated code_snippets
      sprintf(str, *code_snippets).tap do
        @code_snippets = []
      end
    end

    def org_emphasis_regexp
      Regexp.new("(#{pre_emphasis_regexp})" \
                 "(#{markers_regexp})" \
                 "(#{border_forbidden}|" \
                 "#{border_forbidden}#{body_regexp}" \
                 "#{border_forbidden})\\2" \
                 "(?=#{post_emphasis})")
    end

    private

    def pre_emphasis_regexp
      '\s|[-\(\{\'\"]|^'
    end

    def markers_regexp
      '[\*\/_=~\+]'
    end

    def border_forbidden
      '\S'
    end

    def post_emphasis
      '\s|[-,\.;:!\?\'"\)\}\]]|$'
    end

    def body_regexp
      '.*?(?:\\n.*?){0,1}'
    end

    def org_footnote_regexp
      /\[fn:(.+?)(:(.*))?\]/
    end

    def org_footnote_def_regexp
      /^\[fn:(.+?)(:(.*))?\]( (.+))?/
    end

    def org_angle_link_text_regexp
      /<(\w+:[^\]\s<>]+)>/
    end
  end
end
