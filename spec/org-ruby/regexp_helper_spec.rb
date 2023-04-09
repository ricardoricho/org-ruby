require 'spec_helper'

module Orgmode
  describe RegexpHelper do
    let(:helper) { RegexpHelper }

    it 'has headline regexp helper' do
      expect(helper.headline).to match "* Headline"
    end
  end
end
