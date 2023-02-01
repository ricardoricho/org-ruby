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

    def horizontal_rule
      /^\s*-{5,}\s*$/
    end

    def inline_example
      /^\s*:\s/
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

    # for an org-mode table, the first non-whitespace character is a
    # | (pipe).
    def table_row
      /^\s*\|/
    end

    # an org-mode table separator has the first non-whitespace
    # character as a | (pipe), then consists of nothing else other
    # than pipes, hyphens, and pluses.
    def table_separator
      /^\s*\|[-|+]*\s*$/
    end

    def tags
      /\s*:(?<tags>[\w:@]+):\s*$/
    end
  end
end
