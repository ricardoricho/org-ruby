require 'spec_helper'

module Orgmode
  describe Headline do
    let(:headline) { Headline.new("* This is a headline") }

    describe 'id' do
      it { expect(headline.id).not_to be_nil }

      it 'is slugify' do
        expect(headline.id).to eq(headline.slugify)
      end
    end

    describe 'slugify' do
      it 'return headline text in lowercase' do
        expect(headline.slugify).to eq 'this-is-a-headline'
      end

      it 'return headline text join replacing spaces with "-"' do
        expect(headline.slugify).to eq 'this-is-a-headline'
      end
    end

    describe 'remove_tags!' do
      it 'does not affect headline without tags' do
        expect(headline.remove_tags!).to be_nil
      end

      context 'when headline has tags' do
        let(:taged_headline) { Headline.new("** Headline :tag1:tag2:") }

        it 'remove tags from headline_text' do
          taged_headline.remove_tags!
          expect(taged_headline.headline_text).to eq "Headline"
        end

        it 'store tags in a tag array' do
          taged_headline.remove_tags!
          expect(taged_headline.tags).to match_array(%w[tag1 tag2])
        end
      end
    end
  end
end
