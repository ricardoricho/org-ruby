module Orgmode
  module LineRegexp
    def blank
      /^\s*$/
    end

    # Lines starting with zero or more whitespace characters
    # followed by one ‘#’ and a whitespace are treated as comments
    def comment
      /^\s*#\s+.*/
    end

    def drawer
      /^\s*:(?<name>[\w\-]+):$/
    end

    def headline
      /^\*+\s+/
    end

    def list_description
      /^\s*(-|\+|\s+[*])\s+(.*\s+|)::($|\s+)/
    end

    def list_ordered
      /^\s*\d+(\.|\))\s+/
    end

    def list_ordered_continue
      /^\[@(\d+)\]\s+/
    end

    def list_unordered
      /^\s*(-|\+|\s+[*])\s+/
    end

    def metadata
      /^\s*(CLOCK|DEADLINE|START|CLOSED|SCHEDULED):/
    end

    def property_item
      /^\s*:(?<key>[\w\-]+):\s*(?<value>.*)$/
    end

    def tags
      /\s*:(?<tags>[\w:@]+):\s*$/
    end
  end
end
