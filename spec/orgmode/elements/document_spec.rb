require 'spec_helper'
module Orgmode
  module Elements
    RSpec.describe Document do
      let(:document) { Document.new }

      describe 'initialize' do
        it 'has empty footnotes' do
          expect(document.footnotes).to be_empty
        end
        it 'has empty targets' do
          expect(document.targets).to be_empty
        end
      end

      describe '#store_target' do
        let(:target_content) { 'Target content' }
        let(:target) { "<<#{target_content}>>" }
        let(:line) { Line.new target }

        it 'save target in targets' do
          document.store_target line
          saved_target = document.targets.last
          expect(saved_target[:content]).to eq target_content
          expect(saved_target[:index]).to be 1
        end

        context 'when line has several targets' do
          let(:line) { Line.new "Line with <<more>> than <<one>> target." }

          it "save all targets" do
            document.store_target line
            contents = document.targets.map { |target| target[:content] }
            expect(contents).to include('more', 'one')
          end
        end
      end
    end
  end
end
