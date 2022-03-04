=begin
Template Name: Boilerplate - Tailwind CSS, Devise, ImportMap, Sidekiq, Payment Processing (Stripe + Pay-Rails), Name of Person and Friendly ID
Author: Jason Bellows
Instructions: $ rails new myapp -d=<postgresql, mysql, sqlite3> -j=importmap -c=tailwind -m template.rb
=end

def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

def add_importmap_gem
  insert_into_file "Gemfile",
    "gem 'importmap-rails'\n\n",
    before: "# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]"
end

def add_gems
  gem 'devise', '~> 4.8'
  gem 'friendly_id', '~> 5.4', '>= 5.4.2'
  gem 'sidekiq', '~> 6.3', '>= 6.3.1'
  gem 'name_of_person', '~> 1.1', '>= 1.1.1'
  gem 'pay', '~> 3.0' # https://github.com/pay-rails/
  gem 'stripe', '>= 2.8', '< 6.0' # I prefer Stripe but you can opt for braintree or paddle too. https://github.com/pay-rails/pay/blob/master/docs/1_installation.md#gemfile
  gem 'importmap-rails' #doing this seperately since this needs to be before the turbo gem
  gem 'tailwindcss-rails'
end

def add_css_bundling
  rails_command "tailwindcss:install"
  # remove tailwind config that gets installed and swap for new one
  remove_file "tailwind.config.js"
end

def add_storage_and_rich_text
  rails_command "active_storage:install"
  rails_command "action_text:install"
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  route "root to: 'home#index'"

  # Create Devise User
  generate :devise, "User", "first_name", "last_name", "admin:boolean"

  # set admin boolean to false by default
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  # name_of_person gem
  append_to_file("app/models/user.rb", "\nhas_person_name\n", after: "class User < ApplicationRecord")
end

def copy_templates
  directory "app", force: true
end

def add_sidekiq
  environment "config.active_job.queue_adapter = :sidekiq"

  insert_into_file "config/routes.rb",
    "require 'sidekiq/web'\n\n",
    before: "Rails.application.routes.draw do"

  content = <<-RUBY
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  RUBY
  insert_into_file "config/routes.rb", "#{content}\n\n", after: "Rails.application.routes.draw do\n"
end

def add_friendly_id
  generate "friendly_id"
end

def add_pay
  rails_command "pay:install:migrations"

  # add pay_customer to user
  # https://github.com/pay-rails/pay/blob/master/docs/1_installation.md#models
  append_to_file("app/models/user.rb", "\npay_customer\n", after: "class User < ApplicationRecord")
end

def add_tailwind_plugins
  #run "yarn add -D @tailwindcss/typography @tailwindcss/forms @tailwindcss/aspect-ratio @tailwindcss/line-clamp"
  #rails_command  "tailwindcss:build"
  copy_file "tailwind.config.js"
  insert_into_file "app/views/shared/_head.html.erb", 
    "<%= stylesheet_link_tag 'tailwind', 'inter-font', 'data-turbo-track': 'reload' %>\n",
    before: "<%= stylesheet_link_tag  'application', 'data-turbolinks-track': 'reload' %>\n"
end

# Main setup
source_paths

#add_importmap_gem
add_gems
rails_command "importmap:install"

after_bundle do
  add_storage_and_rich_text
  add_css_bundling
  add_users
  add_sidekiq
  copy_templates
  add_friendly_id
  add_pay
  add_tailwind_plugins

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit" }

  say
  say "Kickoff app successfully created! 👍", :green
  say
  say "Switch to your app by running:"
  say "$ cd #{app_name}", :yellow
  say
  say "Then run:"
  say "$ ./bin/dev", :green
end
