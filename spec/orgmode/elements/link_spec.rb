require 'spec_helper'

module Orgmode
  module Elements
    RSpec.describe Link do
      describe 'initialize' do
        let(:document) { Document.new }
        let(:url) { "This is a url" }
        let(:link) { Link.new document, url }

        it 'has a document' do
          expect(link.document).not_to be_nil
        end

        it 'has an url' do
          expect(link.url).not_to be_nil
        end

        it 'has a description' do
          expect(link.description).to be_nil
        end

        context 'when description is present' do
          let(:description) { "this is the description" }
          let(:link) { Link.new document, url, description }

          it 'set a description value' do
            expect(link.description).to eq description
          end
        end

        context 'when document has link abbrevitions' do
          let(:url) { "abbrev"}

          before do
            line = Line.new "#+LINK: abbrev long_url"
            document.store_link_abbreviation(line)
          end

          it 'expand url abbreviation' do
            abbreviate_url = "long_url"
            expect(link.url).to eq abbreviate_url
          end
        end
      end

      describe '#html_tag' do
        let(:document) { Document.new }
        let(:url) { "Any url" }
        let(:description) { nil }
        let(:link) { Link.new document, url, description }

        context 'when description is nil' do
          it 'return a html link with the url as description' do
            html_link = "<a href=\"#{url}\">#{url}</a>"
            expect(link.html_tag).to eq html_link
          end
        end

        context 'when description is not nil' do
          let(:description) { "this is the description"}

          it 'return an html link to url with description as text' do
            html_link = "<a href=\"#{url}\">#{description}</a>"
            expect(link.html_tag).to eq html_link
          end
        end

        context 'when url is an image' do
          let(:url) { "an/image/path.png" }

          context 'when description is text' do
            let(:description) { "Text description"}

            it 'return an img tag' do
              img_tag = "<img src=\"#{url}\" alt=\"#{description}\" />"
              expect(link.html_tag).to eq img_tag
            end
          end
        end

        context 'when url is not an image but description is' do
          let(:url) { "link/path" }
          let(:description) { "an_image.jpeg" }

          it 'return an img tag wrapper in a link' do
            img_tag = "<img src=\"#{description}\" alt=\"#{description}\" />"
            link_tag = "<a href=\"#{url}\">#{img_tag}</a>"
            expect(link.html_tag).to eq link_tag
          end
        end

        context 'when document has targets' do
          let(:url) { "target" }

          before do
            line = Line.new "<<target>>"
            document.store_target(line)
          end

          it 'set url to numerated target' do
            target_tag = "<a href=\"#tg.1\">target</a>"
            expect(link.html_tag).to eq target_tag
          end
        end
      end
    end
  end
end
