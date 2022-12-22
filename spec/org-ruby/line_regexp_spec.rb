require 'spec_helper'

module Orgmode
  describe LineRegexp do
    class DummyRegexp
      include LineRegexp
    end
    let(:regexp) { DummyRegexp.new }

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
