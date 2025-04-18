module Orgmode
  module LineRegexp
    def blank
      /^\s*$/
    end

    # 1) block delimiters
    # 2) block type (src, example, html...)
    # 3) switches (e.g. -n -r -l "asdf")
    # 4) header arguments (:hello world)
    def block
      /^\s*#\+(BEGIN|END)_(\w*)\s*([0-9A-Za-z_\-]*)?\s*([^\":\n]*\"[^\"\n*]*\"[^\":\n]*|[^\":\n]*)?\s*([^\n]*)?/i
    end

    # Lines starting with zero or more whitespace characters
    # followed by one ‘#’ and a whitespace are treated as comments
    def comment
      /^\s*#\s+.*/
    end

    def drawer
      /^\s*:(?<name>[\w\-]+):$/
    end

    def footnote_definition
      /^\[fn:(?<label>[\w-]+)\](?<contents>.*)/
    end

    def footnote_reference
      /\[fn:(?<label>[\w-]*)(:?)(?<contents>.*)\]/
    end

    def headline
      /^(?<level>\*+)\s+(?<text>.*)/
    end

    def horizontal_rule
      /^\s*-{5,}\s*$/
    end

    def in_buffer_setting
      /^#\+(?<key>\w+):\s*(?<value>.*)$/
    end

    def include_file
      /^\s*#\+INCLUDE:\s*"(?<file_path>[^"]+)"(?<options>\s+(?<key>[^\s]+)\s+(?<value>.*))?$/i
    end

    def inline_example
      /^\s*:\s/
    end

    def link_abbrev
      /^\s*#\+LINK:\s*(?<text>\w+)\s+(?<url>.+)$/i
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

    def org_link
      /\[\[(?<url>[^\[\]]+)\](\[(?<friendly_text>[^\[\]]+)\])?\]/x
    end

    def property_item
      /^\s*:(?<key>[\w\-]+):\s*(?<value>.*)$/
    end

    def raw_text
      /^(?<spaces>\s*)#\+(?<keyword>\w+):\s*/
    end

    def results_start
      /^\s*#\+RESULTS:\s*(.+)?$/i
    end

    def subp
      /(?<base>\S)(?<type>[_^])((\{(?<text>[^{}]*)\}))/
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

    def target
      /<{2}(?<content>[^<>\n]+)>{2}/
    end
  end
end
