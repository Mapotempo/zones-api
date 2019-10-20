FROM ruby:2.6

RUN apt-get update -qq && apt-get install -y postgresql-client
RUN mkdir /opt/zones-api
WORKDIR /opt/zones-api
COPY Gemfile /opt/zones-api/Gemfile
COPY Gemfile.lock /opt/zones-api/Gemfile.lock
RUN gem install bundler:2.0.2
RUN bundle install
COPY . /opt/zones-api

# Add a script to be executed every time the container starts.
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3000

# Start the main process.
CMD ["rails", "server", "-b", "0.0.0.0"]
