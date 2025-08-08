module Orgmode
  module Elements
    class Link
      attr_reader :url, :description, :document

      def initialize(document, url, description = nil)
        @document = document
        @url = expand(url, document.link_abbreviations)
        @description = description
      end

      def html_tag
        return image_tag if target_image?
        return target_tag unless document.targets.empty?

        "<a href=\"#{url}\">#{description || url}</a>"
      end

      private

      def expand(url, abbreviations)
        return url if abbreviations.nil?
        return url unless abbreviations.has_key?(url)

        abbreviations[url]
      end

      def description_img_tag
        "<img src=\"#{description}\" alt=\"#{description}\" />"
      end

      def find_target(targets = [])
        targets.find do |target|
          target[:content] == description || target[:content] == url
        end
      end

      def image_file?(file)
        RegexpHelper.image_file.match(file)
      end

      def image_tag
        if !image_file?(url)
          "<a href=\"#{url}\">#{description_img_tag}</a>"
        elsif image_file? description
          description_img_tag
        elsif description.nil?
          "<img src=\"#{url}\" alt=\"#{url}\" />"
        else
          "<img src=\"#{url}\" alt=\"#{description}\" />"
        end
      end

      def target_image?
        return @target_image unless @target_image.nil?

        @target_image = image_file?(url) || image_file?(description) || false
      end

      def target_tag
        target = find_target(document.targets)
        link = target ? "#tg.#{target[:index]}" : url

        "<a href=\"#{link}\">#{description || url}</a>"
      end
    end
  end
end
