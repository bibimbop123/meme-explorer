# frozen_string_literal: true
require 'rbconfig'

root = File.expand_path('..', __dir__)
expected = File.read(File.join(root, '.ruby-version')).strip
abort "Use Ruby #{expected}; current Ruby is #{RUBY_VERSION}." unless RUBY_VERSION == expected
abort 'Usage: ruby scripts/isolated_bundle.rb <bundle command> [arguments]' if ARGV.empty?

bootstrap = File.join(root, 'vendor/bundle/bootstrap')
bundle = File.join(bootstrap, 'bin/bundle')
abort 'Isolated Bundler is missing. Follow docs/RUBY_ENVIRONMENT.md first.' unless File.file?(bundle)

environment = {
  'GEM_HOME' => bootstrap,
  'GEM_PATH' => bootstrap,
  'BUNDLE_PATH' => File.join(root, 'vendor/bundle/application'),
  'BUNDLE_GEMFILE' => File.join(root, 'Gemfile'),
  'BUNDLE_DISABLE_SHARED_GEMS' => 'true',
  'BUNDLE_FROZEN' => 'true',
  'BUNDLE_IGNORE_CONFIG' => 'true',
  'RUBYLIB' => nil,
  'RUBYOPT' => nil
}
%w[RUBYLIB RUBYOPT].each do |name|
  environment["BUNDLER_ORIG_#{name}"] = nil
end

# Execute without a shell; preserve arguments, signals and the command's exit code.
# Database/Redis variables are intentionally supplied by the caller, not loaded here.
exec(environment, RbConfig.ruby, bundle, *ARGV, chdir: root)