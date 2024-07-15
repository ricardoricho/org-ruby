module Orgmode
  module Elements
    class Document
      attr_reader :footnotes

      def initialize
        @footnotes = []
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
    end
  end
end
