# Reproducible Ruby environment

Use **Ruby 3.2.1**, matching `.ruby-version`, `Gemfile` and `Gemfile.lock`.
Run from the repository root:

```sh
ruby scripts/check_ruby_environment.rb
```

The command loads Bundler and key native dependencies without connecting to the
database, Redis or production services. Exit 1 means the environment is not ready.
It reports whether `RUBYLIB` is present because that can hide broken installed gems.
Never paste private environment values or credentials into bug reports.

## Known local failure

The inspected RVM Ruby 3.2.1 gem directory contains BCrypt and Date extensions
linked against Ruby 3.4.1. Plain Ruby loading reproduces Date/Psych failures;
Bundler's locked load path
can select working Date/Psych versions, but BCrypt still fails without the override.
Successful tests
using temporary `/tmp` BCrypt/Date builds are evidence about application behavior,
not proof the normal toolchain is repaired. Do not depend on `/tmp` in CI/deployment.

## Isolated installation procedure

Use a clean Ruby 3.2.1 installation or clean development environment with compiler,
PostgreSQL client headers and Ruby development headers available. Do not run
`gem pristine`, `sudo gem install`, or copy native bundles into a shared gemset.

To isolate Bundler and dependencies from contaminated shared gems, use a new,
initially empty local directory (the following paths are ignored by Git):

```sh
export GEM_HOME="$PWD/vendor/bundle/bootstrap"
export GEM_PATH="$GEM_HOME"
unset RUBYLIB
gem install bundler -v 2.6.5 --no-document
export BUNDLE_PATH="$PWD/vendor/bundle/application"
export BUNDLE_DISABLE_SHARED_GEMS=true
export BUNDLE_FROZEN=true
export BUNDLE_IGNORE_CONFIG=true
ruby "$GEM_HOME/bin/bundle" install
ruby scripts/check_ruby_environment.rb
```

Network access is required to install locked dependencies. If RubyGems itself
fails loading Date/Psych before installation starts, stop and rebuild/use a clean
Ruby installation; do not restore the contaminated shared GEM_PATH. Platform
support/build failures require investigation, not a lockfile update by default.
The isolated installation completed on the affected machine; diagnostics pass
without RUBYLIB and bundle check succeeds. Gemfile.lock remained unchanged.
Full isolated backend run: 912 examples, zero failures, seven pending; 71.48%
coverage with both gates passing, exit 0. A second fresh dependency installation
under vendor/bundle/reproduction also passed installation, native diagnostics,
bundle check and the full suite: 912 examples, zero failures, seven pending,
71.48% coverage, exit 0 (47.62s). Both used the same pinned Ruby and isolated
Bundler bootstrap; this is same-machine reproduction, not cross-platform proof.
Shared RVM gem loading remains broken outside isolation.
BUNDLE_IGNORE_CONFIG prevents local Bundler settings overriding isolation/frozen
settings. Keep the same environment exports when running tests.

## Acceptance

### Running commands after installation

The repository wrapper selects the validated local paths, ignores local Bundler
configuration, requires the pinned Ruby, and clears inherited RUBYLIB/RUBYOPT.
It does not install dependencies, edit shared gems or select database services.
It uses argument-safe exec, not shell interpolation:
Bundler may add its own isolated bootstrap library to RUBYLIB; the diagnostic
labels this separately from a native-extension override. Saved Bundler original
RUBYLIB/RUBYOPT values are cleared so they cannot restore the temporary override.

```sh
ruby scripts/isolated_bundle.rb check
ruby scripts/isolated_bundle.rb exec ruby scripts/check_ruby_environment.rb
RACK_ENV=test DATABASE_URL=postgresql://localhost/meme_explorer_gate_a_test \
  REDIS_URL=redis://127.0.0.1:16379/0 \
  ruby scripts/isolated_bundle.rb exec rspec
```

Start disposable Redis yourself before the test command and stop it afterward.
Do not substitute production database or Redis URLs.

1. Diagnostic exits 0 **without RUBYLIB**.
2. `bundle check` succeeds with the locked dependencies.
3. Full RSpec suite passes both coverage gates against an isolated test database
   and disposable Redis, not production services.
4. Repeat from a fresh environment; confirm no shared gems or lockfile changed.

Do not treat dependency loading as browser/crawler acceptance or deployment approval.