require 'spec_helper'

module Orgmode
  describe HeadlineRegexp do
    class DummyRegexp
      include HeadlineRegexp
    end
    let(:regexp) { DummyRegexp.new }

    describe '.comment_headline' do
      it { expect(regexp.comment_headline).to match 'COMMENT ' }
      it { expect(regexp.comment_headline).to match 'COMMENT  ' }
      it { expect(regexp.comment_headline).not_to match 'COMMENT' }
      it { expect(regexp.comment_headline).not_to match ' COMMENT ' }
    end
  end
end
