require 'spec_helper'

module Orgmode
  RSpec.describe HtmlOutputBuffer do
    let(:output) { StringIO.new }
    let(:buffer) { Orgmode::HtmlOutputBuffer.new(output) }

    describe '.new' do
      it 'has an output buffer' do
        expect(buffer).not_to be_nil
        expect(buffer.output).to eq output
      end

      it 'has HTML buffer_tag' do
        expect(buffer.buffer_tag).to eq 'HTML'
      end

      context 'when call with a document' do
        let(:document) { "This is a document" }
        let(:buffer) { Orgmode::HtmlOutputBuffer.new(output, document)}

        it 'has a document' do
          expect(buffer.document).to eq document
        end

        it 'has empty options' do
          expect(buffer.options).to be_empty
        end
      end

      context 'when call with options' do
        let(:options) { { option: 'value'} }
        let(:buffer) { Orgmode::HtmlOutputBuffer.new(output, nil, options)}

        it 'has nil document' do
          expect(buffer.document).to be_nil
        end

        it 'has options' do
          expect(buffer.options).to eq options
        end
      end
    end

    describe '#wrap_html' do
      let(:document) { double }
      let(:buffer) { Orgmode::HtmlOutputBuffer.new(output, document, parser_options)}

      context 'when parser options include wrap_html' do
        before do
          allow(document).to receive(:title) { "Title" }
        end

        let(:parser_options) { { wrap_html: { title: "Foo" } } }
        it 'insert html headers into output' do
          buffer.wrap_html(parser_options[:wrap_html])
          expect(output.string).to eq "<!DOCTYPE html>\n<html>\n  <head>\n    <title>Title</title>\n\n  </head>\n  <body>\n"
        end
      end

      context 'when wrap_html inlcude css_files' do
        let(:css_files) { ["monokai.css"]}

        before do
          allow(document).to receive(:title) { "Title" }
        end

        let(:parser_options) { { wrap_html: { css_files: css_files } } }
        it 'insert html head and link of files' do
          prefix = "<!DOCTYPE html>\n<html>\n  <head>\n    <title>Title</title>\n"
          sufix ="\n  </head>\n  <body>\n"
          linkrel = "    <link rel=\"stylesheet\" type=\"text/css\" href=\"monokai.css\">"
          buffer.wrap_html(parser_options[:wrap_html])
          expect(output.string).to eq prefix + linkrel + sufix
        end
      end
    end

    describe '#push_mode' do
      before do
        output.write "Buffer"
      end

      context 'when mode is a HtmlBlockTag' do
        let(:mode) { :paragraph }
        let(:indent) { :some_value }
        let(:properties) { Hash.new }

        it 'push HtmlBlock to the output buffer' do
          buffer.push_mode(mode, indent, properties)
          expect(buffer.output.string).to eq 'Buffer<p>'
        end

        context 'when mode is example' do
          let(:mode) { :example }
          it 'sets class attributes to example' do
            buffer.push_mode(mode, indent)
            expect(buffer.output.string).to eq 'Buffer<pre class="example">'
          end
        end

        context 'when mode is inline_example' do
          let(:mode) { :inline_example }
          it 'sets class attributes to example' do
            buffer.push_mode(mode, indent)
            expect(buffer.output.string).to eq 'Buffer<pre class="example">'
          end
        end

        context 'when mode is center' do
          let(:mode) { :center }
          it 'sets style attribute to text-align: center' do
            buffer.push_mode(mode, indent)
            expect(buffer.output.string).to eq 'Buffer<div style="text-align: center">'
          end
        end

        context 'when mode is src' do
          let(:mode) { :src }

          context 'when Buffer options include skip_syntax_highlight = true' do
            let(:buffer) { Orgmode::HtmlOutputBuffer.new(output, nil, { skip_syntax_highlight: true })}
            before(:each) do
              allow(buffer).to receive(:block_lang).and_return('')
            end

            it 'sets class attributes' do
              buffer.push_mode(mode, indent)
              expect(buffer.output.string).to eq 'Buffer<pre class="src">'
            end

            context 'when Buffer block_lang is not empty' do
              let(:block_lang) { 'elisp' }

              before(:each) do
                allow(buffer).to receive(:block_lang).and_return(block_lang)
              end

              it 'set lang attribute' do
                buffer.push_mode(mode, indent, properties)
                expect(buffer.output.string).to eq 'Buffer<pre class="src" lang="elisp">'
              end
            end
          end
        end

        context 'when called for second time' do
          before(:each) do
            buffer.push_mode(mode, indent)
          end

          it 'does not add paragprah' do
            mode = :src
            buffer.push_mode(mode, 'indent')
            expect(buffer.output.string).not_to match(/\Z\n/)
          end
        end
      end
    end

    describe '.rewrite_sub_superscripts' do
      let(:text) { 'This is a sub_{script} text.'}
      it 'replace subscripts' do
        expected = "This is a sub@@html:<sub>@@script@@html:</sub>@@ text."
        expect(buffer.rewrite_sub_superscripts(text)).to eq expected
      end
      it 'replace superscripts' do
        text = 'This is a sup^{script} text.'
        expected = "This is a sup@@html:<sup>@@script@@html:</sup>@@ text."
        expect(buffer.rewrite_sub_superscripts(text)).to eq expected
      end
    end
  end
end
