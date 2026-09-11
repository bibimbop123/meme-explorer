# NOTE: this repo's actual production deploy target (Render.com, see
# render.yaml) defines its own startCommand for both services, which
# takes priority over this Procfile - `bundle exec rackup config.ru -p
# $PORT` for web, matching this file's worker line for the worker. If
# you edit deploy commands, edit render.yaml; this file is effectively
# unused on Render and is kept only for compatibility with Procfile-native
# platforms (e.g. Heroku) if this app is ever deployed there instead.
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml
