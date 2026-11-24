require 'spec_helper'

module Orgmode
  describe Line do
    describe "buffer_setting?" do
      let(:line) { Orgmode::Line.new(buffer_setting) }

      context "when is not a 'comment' paragraph" do
        let(:buffer_setting) { "#+OPTION: option" }
        it "ignore buffer seetting" do
          line = Orgmode::Line.new buffer_setting, nil, :other
          expect(line.buffer_setting).to be_falsy
        end
      end

      context "when it's an title tag" do
        let(:buffer_setting) { "#+TITLE: Setting"}
        it  { expect(line.buffer_setting?).to be_truthy }
      end

      context "when it's a keword defintition" do
        let(:buffer_setting) { "#+TODO: STATE WAITING | DONE"}
        it  { expect(line.buffer_setting?).to be_truthy }
      end
    end

    describe "buffer_setting" do
      let(:line) { Orgmode::Line.new buffer_setting}

      context "when is not a buffer setting" do
        let(:buffer_setting) { "Not a buffer setting" }
        it "do nothing" do
          expect(line.buffer_setting).to be_nil
        end
      end

      context "when is a buffer setting" do
        let(:buffer_setting) { "#+KEY: VALUE" }
        it "yield key value to a given block" do
          line.buffer_setting do |key, value|
            expect(key).to eq "KEY"
            expect(value).to eq "VALUE"
          end
        end
      end
    end

    describe '#headline?' do
      it "recognize headlines that start with asterisks" do
        line = Orgmode::Line.new("*** test\n")
        expect(line.headline?).to be_truthy
      end

      it "reject lines without asteriks at the beginning" do
        line = Orgmode::Line.new("  nope!")
        expect(line.headline?).to be_nil
        line = Orgmode::Line.new("  tricked you!!!***")
        expect(line.headline?).to be_nil
      end
    end

    describe "footnote?" do
      let(:line) { Orgmode::Line.new(footnote) }

      context "when it's a definition footnotes" do
        let(:footnote) { "[fn:label] An its definition" }

        it { expect(line.footnote?).to be_truthy }
      end

      context "when it's a reference footnote" do
        let(:footnote) { "This line has [fn:a:footnote:with definition]" }
        it { expect(line.footnote?).to be_truthy }
      end

      context "recognize anonymous footnotes" do
        let(:footnote) { "Also works [fn::Anonymous] footnotes" }

        it { expect(line.footnote?).to be_truthy }
      end
    end

    describe '#paragraph_type' do
      context 'when line is empty: ""' do
        let(:line) { Orgmode::Line.new("") }

        it { expect(line.paragraph_type).to be :blank }
      end
      context 'when line is a numbered list: 31. list' do
        let(:line) { Orgmode::Line.new("31. foo") }

        it { expect(line.paragraph_type).to be :list_item }
      end
      context 'when line is a list item: - [] list' do
        let(:line) { Orgmode::Line.new("- [ ] checkbox") }

        it { expect(line.paragraph_type).to be :list_item }
      end
      context 'when line is a normal line' do
        let(:line) { Orgmode::Line.new("hello!") }

        it { expect(line.paragraph_type).to be :paragraph}
      end
    end

    # Maybe this could be another class of line: block line.
    describe 'block_should_be_exported?' do
      context "when line describe an export block" do
        let(:line) { Line.new "#+begin_exports ruby" }

        it { expect(line.block_should_be_exported?).to be_truthy }
      end

      context "when line describe a block" do
        let(:line) { Line.new "#+begin_src ruby" }
        it { expect(line.block_should_be_exported?).to be_truthy }

        it 'does not export if exports is none' do
          line = Line.new "#+begin_src ruby :exports none"
          expect(line.block_should_be_exported?).to be_falsy
        end

                it 'does not export if exports is results' do
          line = Line.new "#+begin_src ruby :exports results"
          expect(line.block_should_be_exported?).to be_falsy
        end

        it 'export when :exports is code' do
          line = Line.new "#+begin_src ruby :exports code"
          expect(line.block_should_be_exported?).to be_truthy
        end

        it 'export when exports both' do
          line = Line.new "#+begin_src ruby :exports both"
          expect(line.block_should_be_exported?).to be_truthy
        end
      end
    end
  end
end
