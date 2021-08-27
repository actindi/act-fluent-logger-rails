FROM ruby

WORKDIR /act-fluent-logger-rails

ADD Gemfile act-fluent-logger-rails.gemspec .git ./
ADD lib/act-fluent-logger-rails/version.rb ./lib/act-fluent-logger-rails/version.rb
RUN bundle install

ENTRYPOINT ["bundle", "exec"]
