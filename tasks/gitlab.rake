require 'org-ruby'

namespace :gitlab do
  desc "Build gitlab page"
  task :page do
    index = File.open File.expand_path("README.org")
    index_content = IO.readlines(index)
    parser_options = { wrap_html: { css_files: ["monokai.css"] } }
    parser = Orgmode::Parser.new(index_content, parser_options)
    public_dir = File.expand_path("public")
    Dir.mkdir(public_dir) unless Dir.exist?(public_dir)
    output = File.expand_path("index.html", "public")
    file = File.new(output, 'w')
    file.write(parser.to_html)
    file.close
  end
end
