require 'spec_helper'

module Orgmode
  describe RegexpHelper do
    let(:helper) { RegexpHelper }

    it 'has headline regexp helper' do
      expect(helper.headline).to match "* Headline"
    end

    describe 'rewrite_footnote' do
      let(:helper) { RegexpHelper.new }

      context 'when is a footnote description' do
        it 'yields label and contents from footnote' do
          helper.rewrite_footnote_definition("[fn:label]") do |label, contents|
            expect(label).to eq 'label'
            expect(contents).to eq ''
          end
          helper.rewrite_footnote_definition("[fn:label] description]") do |label, contents|
            expect(label).to eq 'label'
            expect(contents).to eq ' description]'
          end
        end
      end

      context 'when is a footnote reference' do
        it 'yields label and contents from footnote' do
          helper.rewrite_footnote("[fn:label]") do |label, contents|
            expect(label).to eq 'label'
            expect(contents).to eq ''
          end
          helper.rewrite_footnote("[fn:label:contents]") do |label, contents|
            expect(label).to eq 'label'
            expect(contents).to eq 'contents'
          end
          helper.rewrite_footnote("[fn::contents]") do |label, contents|
            expect(label).to eq ''
            expect(contents).to eq 'contents'
          end
        end

        example do
          helper.rewrite_footnote("Other [fn:footnote:with content]") do |label, content|
            expect(label).to eq 'footnote'
            expect(content).to eq 'with content'
          end
        end
      end
    end
  end
end
