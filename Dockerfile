# Org-ruby Dockerfile
FROM ruby:alpine

RUN mkdir org-ruby
COPY Gemfile org-ruby/Gemfile
COPY org-ruby.gemspec org-ruby/org-ruby.gemspec
COPY lib/org-ruby/version.rb org-ruby/lib/org-ruby/version.rb

WORKDIR org-ruby
RUN bundle install

# Run this on changes
ENTRYPOINT ["sh", "-c"]
