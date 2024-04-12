FROM ruby:3.2.3-bookworm

# lsof is required by guard
RUN apt-get update && apt-get install -y lsof

RUN mkdir /myapp
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN gem install bundler:2.5.9
RUN bundle install
COPY . /myapp

EXPOSE 9292

# Turn notification off because
# the docker image does not have libnotify
CMD ["bundle", "exec", "guard", "-n", "f"]
