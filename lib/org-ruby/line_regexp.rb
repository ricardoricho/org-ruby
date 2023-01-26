module Orgmode
  module LineRegexp
    def headline
      /^\*+\s+/
    end

    def tags
      /\s*:(?<tags>[\w:@]+):\s*$/
    end

    def drawer
      /^\s*:(?<name>[\w\-]+):$/
    end

    def property_item
      /^\s*:(?<key>[\w\-]+):\s*(?<value>.*)$/
    end
  end
end
