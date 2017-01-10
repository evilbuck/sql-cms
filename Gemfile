source 'https://rubygems.org'

ruby "2.3.3"

gem "unicorn" # app server

gem 'rails', '~> 5.0.0'
# gem 'acts_as_list'

# bundle exec rake doc:rails generates the API under doc/api.
# gem 'sdoc', '~> 0.4.0', group: :doc

# DB
gem "pg" # Postgres
gem 'immigrant' # FK constraints
gem 'postgres-copy' # bulk import
gem 'postgresql_cursor' # postgres cursors!!

# K/V store
# gem "redis"

# # Versioning
gem 'paper_trail'

group :development, :test do

  gem 'thin' # appserver

  gem 'annotate'
  # gem 'acts_as_fu'

  gem 'pry-rails'

  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
end

group :development do
  # gem 'slack-notifier'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # gem 'rubocop'
end

group :test do
  # CI is puking all over the place on a later version of this, so we're downgrading.
  gem 'simplecov' #, '~> 0.7.1', require: false

  gem 'rspec'#, '~> 2.14'
  gem 'rspec-rails'#, '~> 2.14'
  gem 'rspec-mocks'#, '~> 2.14'
  gem 'shoulda'

  # gem 'database_cleaner'
  gem 'timecop'

  # gem 'fakeredis'
  gem 'connection_pool'
end

group :staging, :qa, :production do
  # Heroku - avoid deprecation warnings.  Grouped because it fucks up logging in Dev.
  gem 'rails_12factor'
end

# Authentication
gem 'devise'
gem 'devise-async'

# Authorization
gem "cancan"

# Async
# gem "daemons"
gem "sidekiq"

# Monitoring
gem "newrelic_rpm"

# Exception reporting
gem "sentry-raven"

# Admin
gem 'inherited_resources', github: 'activeadmin/inherited_resources' # required to install AA with Rails 5
gem 'activeadmin', github: 'activeadmin'

gem 'factory_girl_rails'
gem 'faker'

# For prompting users in scripts
gem "highline"

# For lightweight requests to remote resources when ActiveResource is overkill
# gem 'rest-client'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
