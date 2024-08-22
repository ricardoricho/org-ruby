# Org-ruby Dockerfile
FROM ruby:alpine

# Development tools like: flog
RUN mkdir /org-ruby
COPY Gemfile /org-ruby/Gemfile
COPY org-ruby.gemspec /org-ruby/org-ruby.gemspec
COPY lib/org-ruby/version.rb /org-ruby/lib/org-ruby/version.rb

# Ensure gems are installed on a persistent volume and available as bins
# Make the folder world writable to let the default user install the gems
RUN mkdir /bundle && chmod -R ugo+rwt /bundle
VOLUME /bundle
ENV BUNDLE_PATH='/bundle'
ENV PATH="/bundle/ruby/$RUBY_VERSION/bin:${PATH}"

WORKDIR /org-ruby
RUN bundle install

# Run this on changes
ENTRYPOINT ["sh", "-c"]
