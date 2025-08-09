module Orgmode
  module ImageRegexp
    def image_file
      /\.(gif|jpe?g|p(?:bm|gm|n[gm]|pm)|svgz?|tiff?|x[bp]m)/i
    end
  end
end
