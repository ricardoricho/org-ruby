require 'org-ruby'

namespace :documentation do
  desc "Build documentation"
  task :build do
    readme = File.open File.expand_path("README.org")
    parser = Orgmode::Parser.new(IO.readlines(readme))
    public_dir = File.expand_path("public")
    Dir.mkdir(public_dir) unless Dir.exist?(public_dir)
    output = File.expand_path("index.html", "public")
    file = File.new(output, 'w')
    file.write(parser.to_html)
    file.close
  end
end
