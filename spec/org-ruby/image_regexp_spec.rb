require 'spec_helper'

module Orgmode
  RSpec.describe ImageRegexp do
    class DummyRegexp
      include ImageRegexp
    end
    let(:regexp) { DummyRegexp.new }

    describe 'image_file' do
      it { expect(regexp.image_file).to match 'file.jpg' }
      it { expect(regexp.image_file).to match 'file.jpeg' }
      it { expect(regexp.image_file).to match 'file.png' }
      it { expect(regexp.image_file).to match 'file.svg' }
      it { expect(regexp.image_file).to match 'some/path/file.gif' }
      it { expect(regexp.image_file).to match 'other.svgz' }
      it { expect(regexp.image_file).to match 'tiffany.tiff' }
      it { expect(regexp.image_file).to match 'xx.xpm' }
      it { expect(regexp.image_file).to match 'yy.xbm' }

      it { expect(regexp.image_file).not_to match 'file' }
      it { expect(regexp.image_file).not_to match 'path/file/' }
      it { expect(regexp.image_file).not_to match 'file.pdf' }
      it { expect(regexp.image_file).not_to match 'some/file.xml' }
    end
  end
end
