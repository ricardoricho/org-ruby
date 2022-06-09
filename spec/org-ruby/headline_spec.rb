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
  end
end
