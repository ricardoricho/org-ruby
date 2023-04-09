require 'spec_helper'

module Orgmode
  describe LineRegexp do
    class DummyRegexp
      include LineRegexp
    end
    let(:regexp) { DummyRegexp.new }

    describe '.blank' do
      it { expect(regexp.blank).to match '' }
      it { expect(regexp.blank).to match '  ' }
      it { expect(regexp.blank).to match "\t" }
      it { expect(regexp.blank).to match "\r\t \n" }
      it { expect(regexp.blank).not_to match "_" }
    end

    describe '.block' do
      it { expect(regexp.block).to match ' #+begin_src' }
      it { expect(regexp.block).to match ' #+begin_block -s -a' }
      it { expect(regexp.block).to match ' #+end_block :foo' }
      it { expect(regexp.block).to match ' #+end_block -s :foo' }
      it { expect(regexp.block).to match ' #+end_block' }
    end

    describe '.comment' do
      it { expect(regexp.comment).to match '# comment' }
      it { expect(regexp.comment).to match ' # comment' }
      it { expect(regexp.comment).to match "\t #\t comment"}
      it { expect(regexp.comment).not_to match "#comment"}
    end

    describe '.drawer' do
      it { expect(regexp.drawer).to match ':Dra-Wer:' }
      it { expect(regexp.drawer).not_to match ':drawer:p' }
      it 'capture drawer :name' do
        match = regexp.drawer.match(':name:')
        expect(match[:name]).to eq 'name'
      end
    end

    describe '.headline' do
      # should recognize headlines that start with asterisks
      it { expect(regexp.headline).to match "* Headline" }
      it { expect(regexp.headline).not_to match " ** Headline" }
      it { expect(regexp.headline).not_to match "\t\t * Headline" }
      it { expect(regexp.headline).not_to match " Headline" }
      it { expect(regexp.headline).not_to match " Headline **" }

      # should reject improper initialization
      # should properly determine headline level
      # should properly determine headline level with offset
      # should find simple headline text
      # should understand tags
      # should understand a single tag
      # should understand keywords
      # should recognize headlines marked as COMMENT
    end

    describe '.horizontal_rule' do
      # HorizontalRuleRegexp = /^\s*-{5,}\s*$/
      it { expect(regexp.horizontal_rule).to match "-----" }
      it { expect(regexp.horizontal_rule).to match "\t------ " }
      it { expect(regexp.horizontal_rule).to match "---------\t" }
      it { expect(regexp.horizontal_rule).not_to match "----" }
      it { expect(regexp.horizontal_rule).not_to match " ---- " }
    end

    describe '.in_buffer_setting' do
      # /^#\+(\w+):\s*(.*)$/
      it { expect(regexp.in_buffer_setting).to match "#+keyword: value" }
      it { expect(regexp.in_buffer_setting).not_to match " #+space: beginning" }
      it 'captures key and value' do
        match = regexp.in_buffer_setting.match "#+key: value values"
        expect(match[:key]).to eq 'key'
        expect(match[:value]).to eq 'value values'
      end
    end

    describe '.include_file' do
      it { expect(regexp.include_file).not_to match "#+INCLUDE: " }
      it { expect(regexp.include_file).to match '#+INCLUDE: "file"' }
      it 'captures file_path and options' do
        match = regexp.include_file.match '  #+INCLUDE: "file" src val'
        expect(match[:file_path]).to eq 'file'
        expect(match[:options]).to eq ' src val'
        expect(match[:key]).to eq 'src'
        expect(match[:value]).to eq 'val'
      end
    end

    describe '.inline_example' do
      it{ expect(regexp.inline_example).to match ": expamle"}
      it{ expect(regexp.inline_example).to match " :  expamle"}
      it{ expect(regexp.inline_example).to match "\t: expamle"}
      it{ expect(regexp.inline_example).not_to match "inline : expamle"}
    end

    describe '.link_abbrev' do
      it { expect(regexp.link_abbrev).not_to match "#+LINK: url" }
      it { expect(regexp.link_abbrev).to match " #+LINK: url description" }
      it 'caputure url and description' do
        match = regexp.link_abbrev.match "#+LINK: text url"
        expect(match[:text]).to eq 'text'
        expect(match[:url]).to eq 'url'
      end
    end

    describe '.list_description' do
      # Description list items are unordered list items,
      # and contain the separator ‘::’ to distinguish the description term
      # from the description.
      it { expect(regexp.list_description).to match ' - description :: term' }
      it { expect(regexp.list_description).to match ' + description :: term' }
      it { expect(regexp.list_description).to match ' * description :: term' }
    end

    describe '.list_ordered' do
      # Ordered list items start with a numeral followed by either a period or a
      # right parenthesis, such as ‘1.’ or ‘1)’.
      it { expect(regexp.list_ordered).to match '33. item' }
      it { expect(regexp.list_ordered).to match ' 102) item' }
      it { expect(regexp.list_ordered).not_to match ' 2.item' }
      it { expect(regexp.list_ordered).not_to match ' 10)item' }
    end

    describe '.list_ordered_continue' do
      # If you want a list to start with a different value—e.g.,
      # 20—start the text of the item with ‘[@20]’12.
      it { expect(regexp.list_ordered_continue).to match '[@20] item' }
      it { expect(regexp.list_ordered_continue).to match '[@20] item' }
    end

    describe '.list_undordered' do
      # Unordered list items start with ‘-’, ‘+’, or ‘*’ as bullets.
      it { expect(regexp.list_unordered).to match '- list' }
      it { expect(regexp.list_unordered).to match '+ list' }
      it { expect(regexp.list_unordered).to match ' * list' }
      it { expect(regexp.list_unordered).not_to match '* list' }
    end

    describe '.metadata' do
      it { expect(regexp.metadata).to match ' CLOCK:' }
      it { expect(regexp.metadata).to match ' DEADLINE:' }
      it { expect(regexp.metadata).to match ' START:' }
      it { expect(regexp.metadata).to match ' CLOSED:' }
      it { expect(regexp.metadata).to match ' SCHEDULED:' }
    end

    describe '.property_item' do
      it { expect(regexp.property_item).to match ':key:value' }
      it { expect(regexp.property_item).to match ':key: value' }
      it 'capture key and value' do
        match = regexp.property_item.match ':key: 200-23-2 +'
        expect(match[:key]).to eq 'key'
        expect(match[:value]).to eq '200-23-2 +'
      end
    end

    describe '.raw_text' do
      it { expect(regexp.raw_text).to match '#+word:' }
      it { expect(regexp.raw_text).to match ' #+initial_space:' }
      it { expect(regexp.raw_text).to match '#+final_pace: ' }
      it 'capture keyword and spaces' do
        match = regexp.raw_text.match "   #+AUTHOR: name"
        expect(match[:keyword]).to eq 'AUTHOR'
        expect(match[:spaces]).to eq '   '
      end
    end

    describe '.results_start' do
      it { expect(regexp.results_start).to match " #+RESULTS:" }
      it { expect(regexp.results_start).to match " #+RESULTS: " }
      it { expect(regexp.results_start).to match " #+RESULTS: spec " }
    end

    describe '.table_row' do
      it { expect(regexp.table_row).to match "\t |" }
      it { expect(regexp.table_row).to match "\t | table" }
      it { expect(regexp.table_row).to match "|"}
      it { expect(regexp.table_row).to match "||"}
    end

    describe '.table_separator' do
      it { expect(regexp.table_separator).to match "||" }
      it { expect(regexp.table_separator).to match "|--|" }
      it { expect(regexp.table_separator).to match "|++|++" }
      it { expect(regexp.table_separator).to match "|+-+-+|-" }
    end

    describe '.tags' do
      it { expect(regexp.tags).to match ":tag:" }
      it { expect(regexp.tags).to match ":@tag:" }
      it { expect(regexp.tags).to match " :tag:@tag:tags:" }
      it 'captures match under :tags label' do
        match = regexp.tags.match(" :@tag1:tag2:tag3:")
        expect(match[:tags]).to eq "@tag1:tag2:tag3"
      end
      it { expect(regexp.tags).not_to match ":@tag " }
      it { expect(regexp.tags).not_to match ":@tag :" }
      it { expect(regexp.tags).not_to match "@tag:" }
    end
  end
end
