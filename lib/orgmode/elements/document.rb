module Orgmode
  module Elements
    class Document
      attr_reader :headlines, :footnotes, :targets
      attr_accessor :title

      def initialize
        @headlines = []
        @footnotes = []
        @targets = []
        @title = ""
      end

      def store_headline(line)
        headlines.push(line)
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

      def store_target(line)
        return unless line.target?

        line.to_s.scan(RegexpHelper.target) do |match|
          content = match.first
          target_index = @targets.length + 1
          target = { index: target_index, content: content }
          @targets.push(target)
        end
      end
    end
  end
end
