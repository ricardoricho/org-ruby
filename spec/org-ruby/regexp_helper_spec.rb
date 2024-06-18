require 'spec_helper'

module Orgmode
  describe RegexpHelper do
    let(:helper) { RegexpHelper }

    it 'has headline regexp helper' do
      expect(helper.headline).to match "* Headline"
    end

    describe 'capture_footnote_definition' do
      let(:helper) { RegexpHelper.new }
      let(:footnote_text) { '[fn:label] Definition content' }

      it 'capture footnote label and empty definition' do
        helper.capture_footnote_definition("[fn:label]") do |label, content|
          expect(label).to eq 'label'
          expect(content).to eq ''
        end
      end

      it 'caputre footnote with definition' do
        helper.capture_footnote_definition(footnote_text) do |label, content|
          expect(label).to eq 'label'
          expect(content).to eq ' Definition content'
        end
      end

      it 'replace line with an empty string' do
        helper.capture_footnote_definition(footnote_text) do |label, content|
          # do nothing
        end
        expect(footnote_text).to be_empty
      end
    end

    describe 'rewrite_footnote references' do
      let(:helper) { RegexpHelper.new }

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
