require 'spec_helper'

module Orgmode
  describe RegexpHelper do
    describe '#org-emphasis-regexp' do
      let(:helper) { RegexpHelper.new }
      # https://orgmode.org/worg/org-syntax.html#Emphasis_Markers
      it 'match code object' do
        expect(helper.org_emphasis_regexp).to match '~code~'
      end
      it 'match bold object' do
        expect(helper.org_emphasis_regexp).to match '*bold*'
      end
      it 'match italic object' do
        expect(helper.org_emphasis_regexp).to match '/italic/'
      end
      it 'match undeline object' do
        expect(helper.org_emphasis_regexp).to match '_underline_'
      end
      it 'match verbatim object' do
        expect(helper.org_emphasis_regexp).to match '=verbatim='
      end
      it 'match strike-through object' do
        expect(helper.org_emphasis_regexp).to match '+strike-through+'
      end
      # Do not match inside links, need a space after the bracket.
      example { expect(helper.org_emphasis_regexp).not_to match '[[a][~a~]]' }
      example { expect(helper.org_emphasis_regexp).to match '[[a][ ~a~]]' }
    end

    describe '#match_all' do
      let(:helper) { RegexpHelper.new }
      let(:content) do
        "This string contains *bold*, /italic/, and ~verbatim~ +objects+ text."
      end

      it 'scan content looking for all emphasis objects that match an emphasis objects' do
        matches = helper.match_all(content)
        markers = (matches.map { |match| match[1] })
        count = matches.length
        expect(count).to be 4
        expect(markers).to match_array(%w[* / ~ +])
      end

      context 'when content has a link' do
        let(:content) { "[[http://www.bing.com/twitter]]" }

        it "not match in link url" do
          matches = helper.match_all(content)
          expect(matches).to be_empty
        end
      end
    end

    it 'has headline regexp helper' do
      helper = RegexpHelper
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

    describe 'rewrite_emphasis' do
      let(:helper) { RegexpHelper.new }
      let(:content) { "This *text* is /for/ +tests+ specs."}

      it 'yield block with marker and content of match' do
        helper.rewrite_emphasis(content) do |marker, content|
          expect(%w[* / +]).to include(marker)
          expect(%w[text for tests]).to include(content)
        end
      end

      context 'when marker is code' do
        let(:content) { "Text with ~code~ and =verbatim= markers."}

        it 'stores subsitute in code_snippets and left %s to be replaced' do
          helper.rewrite_emphasis(content) do |marker, content|
            case marker
            when '~' then "CODE: #{content}"
            when '=' then "VERBATIM: #{content}"
            end
          end
          expect(content).to eq "Text with %s and %s markers."
          expect(helper.code_snippets).not_to be_empty
          # expect(helpe.code_snippets_stack).to match_array(["CODE: code", "VERBATIM: verbatim"])
        end
      end

      it 'allow quotes within code markup' do
        n = helper.rewrite_emphasis(content) do |marker, content|
          "<marker type=#{marker}>#{content}</marker>"
        end
        code_snippets = helper.restore_code_snippets n
        expect(code_snippets).to eq content
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

      describe 'rewrite_link' do
        let(:helper) { RegexpHelper.new }
        let(:line_content) { "This is [[a link][with body]]" }

        it 'replace links with block content' do
          helper.rewrite_links(line_content) do |url, text|
            expect(url).to eq 'a link'
            expect(text).to eq 'with body'
            'new_link'
          end
          expect(line_content).to eq 'This is new_link'
        end
      end
    end
  end
