module Orgmode
  module Elements
    class Document
      attr_reader :buffer_settings, :headlines, :footnotes, :targets, :options,
                  :custom_keywords, :link_abbreviations
      attr_writer :title

      def initialize
        @buffer_settings = {}
        @custom_keywords = []
        @footnotes = []
        @headlines = []
        @link_abbreviations = {}
        @options = {}
        @targets = []
        @title = ""
      end

      def store_buffer_settings(line)
        line.in_buffer_setting? do |key, value|
          if key == 'OPTIONS'
            # Options are stored in a hash. Special-case.
            value.scan(/([^ ]*):((((\(.*\))))|([^ ])*)/) do |o, v|
              options[o] = v
            end
          elsif key =~ /^(TODO|SEQ_TODO|TYP_TODO)$/
            # Handle todo keywords specially.
            value.split.each do |keyword|
              keyword.gsub!(/\(.*\)/, '') # Get rid of any parenthetical notes
              keyword = Regexp.escape(keyword)
              next if keyword == '\\|' # Special character in the todo format, not really a keyword
              custom_keywords.push keyword
            end
          else
            buffer_settings.store(key, value)
          end
        end
      end

      def store_link_abbreviation(line)
        return unless link = line.link_abbrev?

        link_abbreviations.store(link.first, link.last)
      end

      def store_footnote(line)
        return unless line.footnote?

        if RegexpHelper.footnote_definition.match(line.to_s)
          match = Regexp.last_match
          label = match[:label]
          content = match[:contents]
        elsif RegexpHelper.footnote_reference.match(line.to_s)
          match = Regexp.last_match
          label = match[:label]
          content = match[:contents]
        end
        footnote = @footnotes.find { |footnote| footnote[:label] == label }

        if footnote.nil?
          footnote_index = @footnotes.length + 1
          footnote = { index: footnote_index, label: label, content: content }
          @footnotes.push(footnote)
        else
          footnote[:content] = content
        end
      end

      def store_headline(line)
        headlines.push(line)
      end

      def store_target(line)
        return unless line.target?

        line.to_s.scan(RegexpHelper.target) do |match|
          content = match.first
          target_index = @targets.length + 1
          target = { index: target_index, content: content }
          @targets.push(target)
        end
      end

      def title
        buffer_settings.fetch('TITLE', headlines.first&.output_text)
      end
    end
  end
end
