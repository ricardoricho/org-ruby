module Orgmode

  # Represents a headline in an orgmode file.
  class Headline < Line

    # This is the "level" of the headline
    attr_reader :level

    # This is the headline text -- the part of the headline minus the leading
    # asterisks, the keywords, and the tags.
    attr_reader :headline_text

    # This contains the lines that "belong" to the headline.
    attr_reader :body_lines

    # These are the headline tags
    attr_reader :tags

    # Optional keyword found at the beginning of the headline.
    attr_reader :keyword

    # Valid states for partial export.
    # exclude::       The entire subtree from this heading should be excluded.
    # headline_only:: The headline should be exported, but not the body.
    # all::           Everything should be exported, headline/body/children.

    # ValidExportStates = [:exclude, :headline_only, :all]

    # The export state of this headline. See +ValidExportStates+.
    attr_accessor :export_state

    # Include the property drawer items found for the headline
    attr_accessor :property_drawer

    def initialize(line, parser = nil, offset = 0)
      super(line, parser)
      initialize_properties
      set_properties!(parser, offset)
    end

    def body
      case export_state
      when :exclude
        []
      when :headline_only
        body_lines.take(1)
      when :all
        body_lines
      end
    end

    # Override Line.output_text
    def output_text
      @headline_text
    end

    def id
      slugify
    end

    def remove_tags!
      match = RegexpHelper.tags.match(headline_text)
      return nil if match.nil?

      @tags = match[:tags].split(':')
      @headline_text.slice!($&)
    end

    def store_property(property)
      @property_drawer.store(property[:key], property[:value])
    end

    def remove_keyword!
      match = custom_keywords_regexp.match(headline_text)
      if match
        @headline_text = match[:content]
        @keyword = match[:keyword]
      end
    end

    # Determines if a headline has the COMMENT keyword.
    def comment_headline?
      RegexpHelper.comment_headline.match(headline_text)
    end

    # Overrides Line.paragraph_type.
    def paragraph_type
      "heading#{@level}".to_sym
    end

    def headline_level
      title_offset = parser&.buffer_settings&.fetch('TITLE', nil) ? 1 : 0
      level - title_offset
    end

    def push_body_line(line)
      @body_lines.push line
    end

    private

    def initialize_properties
      @body_lines = []
      @tags = []
      @export_state = :exclude
      @property_drawer = { }
    end

    def set_properties!(parser, offset)
      match = RegexpHelper.headline.match(@line)
      return if match.nil?

      new_offset = parser&.buffer_settings&.fetch('TITLE', nil) ? offset + 1 : offset
      @level = match[:level].length + new_offset
      @headline_text = match[:text]
      remove_tags!
      remove_keyword!
    end

    def custom_keywords_regexp
      keywords = custom_keywords || default_keywords

      Regexp.new("\s*(?<keyword>#{keywords})\s+(?<content>.*)")
    end

    def custom_keywords
      @parser && !@parser.custom_keywords.empty? &&
        @parser.custom_keywords.join('|')
    end

    def default_keywords
      %w[TODO DONE].join('|')
    end
  end
end
