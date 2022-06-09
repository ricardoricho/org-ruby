require 'spec_helper'

describe Orgmode::HtmlOutputBuffer do
  it 'generates html headings ids' do
    examples_dir = File.expand_path(File.join(File.dirname(__FILE__), "html_examples"))
    org_file = File.join(examples_dir, "heading-id.org")
    html_file = File.join(examples_dir, "heading-id-active.html")
    parser_options = { generate_heading_id: true }

    parser = Orgmode::Parser.new(IO.read(org_file), parser_options)
    actual = parser.to_html
    expected = IO.read(html_file)
    expect(actual).to eql(expected)
  end
end
