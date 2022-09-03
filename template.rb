self.source_paths.push __dir__

# say "New rails application with devise gem\n"
# current_ruby = ask("Which version of ruby? 1.8.7 or 1.9.2?")

# run "rvm gemset create #{app_name}"
# run "rvm #{current_ruby}@#{app_name}"
# create_file ".rvmrc", "rvm use #{current_ruby}@#{app_name}"

gem 'devise', '~> 4.8', '>= 4.8.1'
gem_group :development, :test do
  gem 'htmlbeautifier'
  gem 'solargraph', '~> 0.45.0'
  gem 'solargraph-rails', '~> 0.3.1'
  # gem 'faker', git: 'https://github.com/faker-ruby/faker.git', branch: 'master', require: false
end


after_bundle do
  environment "config.application_name = Rails.application.class.module_parent_name"
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'

  # -------------------------------- devise -------------------------------- START
  generate "devise:install"
  generate "devise", "User", "admin:boolean"

  gsub_file "app/models/user.rb", /:recoverable, :rememberable, :validatable/, ":recoverable, :rememberable, :validatable, :trackable" #:confirmable


  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"

    # gsub_file migration, /# t.string   :confirmation_token/, "t.string   :confirmation_token"
    # gsub_file migration, /# t.datetime :confirmed_at/, "t.datetime :confirmed_at"
    # gsub_file migration, /# t.datetime :confirmation_sent_at/, "t.datetime :confirmation_sent_at"
    # gsub_file migration, /# t.string   :unconfirmed_email # Only if using reconfirmable/, "t.string   :unconfirmed_email"

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
  directory "app/views/devise", "app/views/devise"

  # -------------------------------- devise -------------------------------- END
  # route "root 'home#index'"
  generate "controller home index"
  gsub_file 'config/routes.rb', /^\s+get\s'home\/index'/, "\troot 'home#index'"

  get "https://raw.githubusercontent.com/akladyous/rails-devise-template/main/.solargraph.yml", ".solargraph.yml"
  get "https://gist.githubusercontent.com/castwide/28b349566a223dfb439a337aea29713e/raw/715473535f11cf3eeb9216d64d01feac2ea37ac0/rails.rb", "config/initializers/solargraph.rb"

  inject_into_file "app/helpers/application_helper.rb", before: "end" do
    <<-eos
    def feedback_for?(object, attribute)
        return nil if object.errors.empty?
        if object.errors.has_key?(attribute)
            return content_tag :div, nil, { class: ['d-block', 'invalid-feedback'] } do
                resource.errors.full_messages_for(attribute).to_sentence
            end
        end
        nil
    end
    eos
  end

  directory "app/views/application", "app/views/application"
  copy_file "app/views/home/index.html.erb", force: true
  copy_file "app/assets/stylesheets/index.css", force: true
  copy_file "app/views/home/index.html.erb", force: true
  # remove_file "app/views/layouts/application.html.erb"
  # copy_file "app/views/layouts/application.html.erb"
  create_file "app/views/layouts/application.html.erb", force: true do <<~EOF
    <html>
      <head>
        <%= render 'head' %>
      </head>
      <body>
        <header>
            <%= render 'header' %>
        </header>
        <%= content_for :content or yield %>
        <footer>
            <%= render 'footer' %>
        </footer>
      </body>
    </html>
    EOF
  end
  copy_file "app/views/layouts/devise.html.erb"
  copy_file "app/assets/stylesheets/index.css"
  copy_file "app/assets/images/rails.jpeg"
  copy_file "app/assets/images/avatar.jpeg"

  append_to_file ".gitignore" do
    <<~eos
      \n/app/assets/builds/*
      /config/credentials/development.key
      /config/credentials/production.key
      /config/credentials/environment.key
      /config/initializers/secret_token.rb
      /public/assets/builds/*
      /temp/cache/*
    eos
  end

  append_to_file "app/assets/config/manifest.js", "//= link index.css"
  run "rails assets:clobber && rails assets:precompile &&  rm -rf ./public/assets"
  # yard gems
end
