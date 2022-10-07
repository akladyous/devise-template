def source_paths
  [__dir__]
end
# say "New rails application with devise gem\n"
# current_ruby = ask("Which version of ruby? 2.7.4 or 3.0.0 ?")

# run "rvm gemset create #{app_name}"
# run "rvm #{current_ruby}@#{app_name}"
# create_file ".rvmrc", "rvm use #{current_ruby}@#{app_name}"
def app_name_dasherized
  app_name.gsub('_', '-')
end

gem 'devise', '~> 4.8', '>= 4.8.1'
gem 'image_processing', '~> 1.2'
gem_group :development, :test do
  gem 'htmlbeautifier'
  gem 'solargraph', '~> 0.45.0'
  gem 'solargraph-rails', '~> 0.3.1'
  gem 'faker', :git => 'https://github.com/faker-ruby/faker.git', :branch => 'main', require: false
end

after_bundle do

  run 'bundle lock --add-platform aarch64-linux'
  run 'bundle lock --add-platform x86_64-darwin-19'
  run 'bundle lock --add-platform x86_64-linux'
  run 'yarn add validate.js'

  rails_command "active_storage:install"
  rails_command "generate stimulus imageLoader"
  rails_command "generate stimulus validate"

  environment "config.application_name = Rails.application.class.module_parent_name"
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
  # -------------------------------- devise -------------------------------- START
  generate "devise:install"
  generate "devise", "User", "admin:boolean"

  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"

    gsub_file migration, /# t.integer  :sign_in_count, default: 0, null: false/, "t.integer  :sign_in_count, default: 0, null: false"
    gsub_file migration, /# t.datetime :current_sign_in_at/, "t.datetime :current_sign_in_at"
    gsub_file migration, /# t.datetime :last_sign_in_at/, "t.datetime :last_sign_in_at"
    gsub_file migration, /# t.string   :current_sign_in_ip/, "t.string   :current_sign_in_ip"
    gsub_file migration, /# t.string   :last_sign_in_ip/, "t.string   :last_sign_in_ip"
  end

  gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  inject_into_file "config/initializers/devise.rb", "  config.navigational_formats = ['/', :html, :turbo_stream]", after: "Devise.setup do |config|\n"
  inject_into_file 'config/initializers/devise.rb', after: "# ==> Warden configuration\n" do <<-EOF
    config.warden do |manager|
      manager.failure_app = TurboFailureApp
    end
    EOF
  end
  inject_into_file "config/initializers/devise.rb", before: "# frozen_string_literal: true" do <<~EOF
    class TurboFailureApp < Devise::FailureApp
      def respond
          if request_format == :turbo_stream
          redirect
          else
              super
          end
      end

      def skip_format?
        %w(html turbo_stream */*).include? request_format.to_s
      end
    end
    EOF
  end

  # -------------------------------- devise -------------------------------- END
  generate "controller home index"
  gsub_file 'config/routes.rb', /^\s+get\s'home\/index'/, "\troot 'home#index'"
  append_to_file ".gitignore" do
    <<~eos
      \n/app/assets/builds/*
      /config/credentials/development.key
      /config/credentials/production.key
      /config/credentials/environment.key
      /config/initializers/secret_token.rb
      /public/assets/builds/*
      /tmp/cache/*
    eos
  end

  append_to_file "app/javascript/application.js" do
    <<~eos
      \n
      document.addEventListener('DOMContentLoaded', function (event) {
          const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
          const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl))
      })
    eos
  end
  append_to_file "app/assets/config/manifest.js", "//= link index.css"

  get "https://raw.githubusercontent.com/akladyous/rails-devise-template/main/.solargraph.yml", ".solargraph.yml"
  get "https://gist.githubusercontent.com/castwide/28b349566a223dfb439a337aea29713e/raw/715473535f11cf3eeb9216d64d01feac2ea37ac0/rails.rb", "config/initializers/solargraph.rb"

  remove_file "config/database.yml"
  template    "config/database.yml.erb", "config/database.yml"
  remove_file "app/controllers/application_controller.rb"
  copy_file   "app/controllers/application_controller.rb"


  remove_file "app/controllers/concerns/devise_params.rb"
  copy_file   "app/controllers/concerns/devise_params.rb"
  remove_file "app/helpers/application_helper.rb"
  copy_file   "app/helpers/application_helper.rb"
  remove_file "app/models/user.rb"
  copy_file   "app/models/user.rb"

  copy_file   "app/assets/stylesheets/index.css", force: true
  copy_file   "app/assets/images/rails.jpeg"
  copy_file   "app/assets/images/avatar.jpeg"
  directory   "app/views/application", "app/views/application"
  directory   "app/views/devise", "app/views/devise"
  copy_file   "app/views/home/index.html.erb", force: true
  copy_file   "app/views/layouts/devise.html.erb"
  remove_file "app/views/layouts/application.html.erb"
  copy_file   "app/views/layouts/application.html.erb"

  remove_file "app/javascript/controllers/image_loader_controller.js"
  copy_file   "app/javascript/controllers/image_loader_controller.js"
  remove_file "app/javascript/controllers/validate_controller.js"
  copy_file   "app/javascript/controllers/validate_controller.js"

  directory   "app/form_builders", "app/form_builders"

  template    './docker_files/.dockerignore.erb', '.dockerignore'
  template    './bin/entrypoint.sh.erb', 'bin/entrypoint.sh'
  template    './bin/run.sh.erb', 'bin/run.sh'
  run         'chmod +x ./bin/entrypoint.sh'


  run "rails assets:clobber && rails assets:precompile &&  rm -rf ./public/assets"
  # yard gems
end
