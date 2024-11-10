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
          expect(taged_headline.headline_text).to eq 'Headline'
        end

        it 'store tags in a tag array' do
          expect(taged_headline.tags).to match_array(%w[tag1 tag2])
        end
      end
    end

    describe 'remove_keyword!' do
      it 'does not affect headline without keywords' do
        expect(headline.headline_text).to eq 'This is a headline'
      end

      context 'when headline has keyword' do
        let(:keyword_headline) { Headline.new("** TODO Headline :tag:") }

        it 'remove keyword from headline_text' do
          expect(keyword_headline.headline_text).to eq "Headline"
        end

        it 'store tags in a tag array' do
          expect(keyword_headline.keyword).to eq "TODO"
        end

        context 'when Parser has custom keywords' do
          let(:keywords) { %w[THIS ARE ORG KEYWORDS] }
          let(:parser) { double }
          let(:headline) { Headline.new("** ARE Headline", parser) }

          before do
            allow(parser).to receive(:buffer_settings).and_return Hash.new
            allow(parser).to receive(:custom_keywords).and_return(keywords)
          end

          it 'use parser expresion to retrive keywords' do
            expect(headline.headline_text).to eq "Headline"
          end

          example 'Other keyword' do
            line = Headline.new("** KEYWORDS  Text", parser)
            expect(line.headline_text).to eq 'Text'
          end

          example 'Trick keyword' do
            line = Headline.new("** Y Text", parser)
            expect(line.headline_text).to eq 'Y Text'
          end
        end
      end
    end
  end
end
