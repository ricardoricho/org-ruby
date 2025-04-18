module Orgmode

  # Represents a single line of an orgmode file.
  class Line

    # The indent level of this line. this is important to properly translate
    # nested lists from orgmode to textile.
    # TODO 2009-12-20 bdewey: Handle tabs
    attr_reader :indent

    # Backpointer to the parser that owns this line.
    attr_reader :parser

    # Paragraph type determined for the line.
    attr_reader :paragraph_type

    # Major modes associate paragraphs with a table, list and so on.
    attr_reader :major_mode

    # A line can have its type assigned instead of inferred from its
    # content. For example, something that parses as a "table" on its
    # own ("| one | two|\n") may just be a paragraph if it's inside
    # #+BEGIN_EXAMPLE. Set this property on the line to assign its
    # type. This will then affect the value of +paragraph_type+.
    attr_accessor :assigned_paragraph_type

    # In case more contextual info is needed we can put here
    attr_accessor :properties

    def initialize(line, parser = nil, assigned_paragraph_type = nil)
      @parser = parser
      @line = line
      @indent = 0
      @line =~ /\s*/
      @assigned_paragraph_type = assigned_paragraph_type
      @properties = { }
      determine_paragraph_type
      determine_major_mode
      extract_properties
      @indent = $&.length unless blank?
    end

    def to_s
      @line
    end

    def slugify
      output_text
        .downcase
        .gsub(/\s+/, '-') # replace spaces with -
        .gsub(/[^a-zA-Z0-9_-]/, '') # remove non-alphanumeric characters
    end

    # Tests if a line is a comment.
    def comment?
      return @assigned_paragraph_type == :comment if @assigned_paragraph_type
      return block_type.casecmp("COMMENT") if begin_block? || end_block?

      RegexpHelper.comment.match(@line)
    end

    # Determines if a line is an orgmode "headline":
    # A headline begins with one or more asterisks.
    def headline?
      RegexpHelper.headline.match(@line)
    end

    def footnote?
      RegexpHelper.footnote_definition.match(@line) ||
        RegexpHelper.footnote_reference.match(@line)
    end

    def target?
      RegexpHelper.target.match(@line)
    end

    def property_drawer_begin_block?
      match = RegexpHelper.drawer.match(@line)
      match && match[:name].downcase == 'properties'
    end

    def property_drawer_end_block?
      match = RegexpHelper.drawer.match(@line)
      match && match[:name].downcase == 'end'
    end

    def property_drawer_item?
      RegexpHelper.property_item.match(@line)
    end

    # Tests if a line contains metadata instead of actual content.
    def metadata?
      check_assignment_or_regexp(:metadata, RegexpHelper.metadata)
    end

    def nonprinting?
      comment? || metadata? || begin_block? || end_block? || include_file?
    end

    def blank?
      check_assignment_or_regexp(:blank, RegexpHelper.blank)
    end

    def plain_list?
      ordered_list? or unordered_list? or definition_list?
    end

    def unordered_list?
      check_assignment_or_regexp(:unordered_list, RegexpHelper.list_unordered)
    end

    def strip_unordered_list_tag
      @line.sub(RegexpHelper.list_unordered, "")
    end

    def definition_list?
      check_assignment_or_regexp(:definition_list,
                                 RegexpHelper.list_description)
    end

    def ordered_list?
      check_assignment_or_regexp(:ordered_list, RegexpHelper.list_ordered)
    end

    def strip_ordered_list_tag
      line = @line.sub(RegexpHelper.list_ordered, "")
      if line =~ RegexpHelper.list_ordered_continue
        line = line.sub(RegexpHelper.list_ordered_continue, "")
      end
      line
    end

    def extract_properties
      if @line =~ RegexpHelper.list_ordered
        line_without_number =  @line.sub(RegexpHelper.list_ordered, "")
        if line_without_number =~ RegexpHelper.list_ordered_continue
          # Extract the start of the ordered list and store it in
          # properties
          @properties["li"] =
            line_without_number.match(RegexpHelper.list_ordered_continue)[1]
        end
      end
    end

    def horizontal_rule?
      check_assignment_or_regexp(:horizontal_rule, RegexpHelper.horizontal_rule)
    end

    # Extracts meaningful text and excludes org-mode markup,
    # like identifiers for lists or headings.
    def output_text
      return strip_ordered_list_tag if ordered_list?
      return strip_unordered_list_tag if unordered_list?
      return @line.sub(RegexpHelper.inline_example, "") if inline_example?
      return strip_raw_text_tag if raw_text?

      @line
    end

    def plain_text?
      not metadata? and not blank? and not plain_list?
    end

    def table_row?
      check_assignment_or_regexp(:table_row, RegexpHelper.table_row)
    end

    def table_separator?
      check_assignment_or_regexp(:table_separator, RegexpHelper.table_separator)
    end

    # Checks if this line is a table header.
    def table_header?
      @assigned_paragraph_type == :table_header
    end

    def table?
      table_row? or table_separator? or table_header?
    end

    def begin_block?
      match = RegexpHelper.block.match(@line)
      match && match[1].downcase == 'begin'
    end

    def end_block?
      match = RegexpHelper.block.match(@line)
      match && match[1].downcase == 'end'
    end

    def block_type
      $2 if RegexpHelper.block.match(@line)
    end

    def block_lang
      $3 if RegexpHelper.block.match(@line)
    end

    def code_block?
      block_type =~ /^(EXAMPLE|SRC)$/i
    end

    def block_switches
      $4 if RegexpHelper.block.match(@line)
    end

    def block_header_arguments
      header_arguments = { }

      if RegexpHelper.block.match(@line)
        header_arguments_string = $5
        harray = header_arguments_string.split(' ')
        harray.each_with_index do |arg, i|
          next_argument = harray[i + 1]
          if arg =~ /^:/ and not (next_argument.nil? or next_argument =~ /^:/)
            header_arguments[arg] = next_argument
          end
        end
      end

      header_arguments
    end

    # TODO: COMMENT block should be considered here
    def block_should_be_exported?
      export_state = block_header_arguments[':exports']
      ['both', 'code', nil, ''].include?(export_state) ||
        !['none', 'results'].include?(export_state)
    end

    def results_block_should_be_exported?
      export_state = block_header_arguments[':exports']
      ['results', 'both'].include?(export_state) ||
        !['code', 'none', nil, ''].include?(export_state)
    end

    # Test if the line matches the "inline example" case:
    # the first character on the line is a colon.
    def inline_example?
      check_assignment_or_regexp(:inline_example, RegexpHelper.inline_example)
    end

    # Checks if this line is raw text.
    def raw_text?
      check_assignment_or_regexp(:raw_text, RegexpHelper.raw_text)
    end

    def raw_text_tag
      match = RegexpHelper.raw_text.match(@line)
      match && match[:keyword].upcase
    end

    def strip_raw_text_tag
      @line.sub(RegexpHelper.raw_text) { |match| $1 }
    end

    # call-seq:
    #     line.in_buffer_setting?         => boolean
    #     line.in_buffer_setting? { |key, value| ... }
    #
    # Called without a block, this method determines if the line
    # contains an in-buffer setting. Called with a block, the block
    # will get called if the line contains an in-buffer setting with
    # the key and value for the setting.
    def in_buffer_setting?
      return false if @assigned_paragraph_type &&
                      @assigned_paragraph_type != :comment
      match = RegexpHelper.in_buffer_setting.match(@line)

      if block_given?
        if match
          yield match[:key], match[:value]
        end
      else
        match
      end
    end

    # #+TITLE: is special because even though that it can be
    # written many times in the document, its value will be that of the last one
    def title?
      @assigned_paragraph_type == :title
    end

    def start_of_results_code_block?
      @line =~ RegexpHelper.results_start
    end

    def link_abbrev?
      match = RegexpHelper.link_abbrev.match(@line)
      match && [match[:text], match[:url]]
    end

    def include_file?
      RegexpHelper.include_file.match(@line)
    end

    def include_file_path
      match = RegexpHelper.include_file.match(@line)
      match && File.expand_path(match[:file_path])
    end

    def include_file_options
      match = RegexpHelper.include_file.match(@line)
      match && match[:options] && [match[:key], match[:value]]
    end

    # Determines the paragraph type of the current line.
    def determine_paragraph_type
      @paragraph_type = \
      case
      when blank?
        :blank
      when definition_list? # order is important! A definition_list is also an unordered_list!
        :definition_term
      when (ordered_list? or unordered_list?)
        :list_item
      when property_drawer_begin_block?
        :property_drawer_begin_block
      when property_drawer_end_block?
        :property_drawer_end_block
      when property_drawer_item?
        :property_drawer_item
      when metadata?
        :metadata
      when block_type
        if block_should_be_exported?
          case block_type.downcase.to_sym
          when :center, :comment, :example, :html, :quote, :src
            block_type.downcase.to_sym
          else
            :comment
          end
        else
          :comment
        end
      when title?
        :title
      when raw_text? # order is important! Raw text can be also a comment
        :raw_text
      when comment?
        :comment
      when table_separator?
        :table_separator
      when table_row?
        :table_row
      when table_header?
        :table_header
      when inline_example?
        :inline_example
      when horizontal_rule?
        :horizontal_rule
      else :paragraph
      end
    end

    # Order is important. A definition_list is also an unordered_list
    def determine_major_mode
      @major_mode = \
      case
      when definition_list?
        :definition_list
      when ordered_list?
        :ordered_list
      when unordered_list?
        :unordered_list
      when table?
        :table
      end
    end

    ######################################################################
    private

    # This function is an internal helper for determining the paragraph
    # type of a line... for instance, if the line is a comment or contains
    # metadata. It's used in routines like blank?, plain_list?, etc.
    #
    # What's tricky is lines can have assigned types, so you need to check
    # the assigned type, if present, or see if the characteristic regexp
    # for the paragraph type matches if not present.
    #
    # call-seq:
    #     check_assignment_or_regexp(assignment, regexp) => boolean
    #
    # assignment:: if the paragraph has an assigned type, it will be
    #              checked to see if it equals +assignment+.
    # regexp::     If the paragraph does not have an assigned type,
    #              the contents of the paragraph will be checked against
    #              this regexp.
    def check_assignment_or_regexp(assignment, regexp)
      return @assigned_paragraph_type == assignment if @assigned_paragraph_type
      @line =~ regexp
    end
  end
end
