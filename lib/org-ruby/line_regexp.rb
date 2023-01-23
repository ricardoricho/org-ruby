module Orgmode
  module LineRegexp
    def headline
      /^\*+\s+/
    end

    def tags
      /\s*:(?<tags>[\w:@]+):\s*$/
    end
  end
end
