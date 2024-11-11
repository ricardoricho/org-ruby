require 'org-ruby'

namespace :github do
  desc "Build page"
  task :pages do
    readme = File.open File.expand_path('README.org')
    readme_content = IO.readlines(readme)
    parser_options = { wrap_html: { css_files: ["monokai.css"] } }
    parser = Orgmode::Parser.new(readme_content, parser_options)
    public_dir = File.expand_path("public")
    Dir.mkdir(public_dir) unless Dir.exist?(public_dir)
    output = File.expand_path("index.html", "public")
    index = File.new(output, 'w')
    index.write(parser.to_html)
    index.close
  end
end
