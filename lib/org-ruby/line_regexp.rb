module Orgmode
  module LineRegexp
    # Lines starting with zero or more whitespace characters
    # followed by one ‘#’ and a whitespace are treated as comments
    def comment
      /^\s*#\s+.*/
    end

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
