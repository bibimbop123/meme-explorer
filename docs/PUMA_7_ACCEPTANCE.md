# Puma 7.2.1 upgrade acceptance

## Local changes

- Puma 6.6.1 → 7.2.1; Gemfile `~> 7.2.1` keeps the patched 7.2 series.
- Native extension builds/loads on pinned Ruby 3.2.1, macOS arm64.
- Renamed configured `on_worker_boot` to Puma 7's `before_worker_boot`.
- No deployment start command, feed flag or production environment changed.

Reviewed installed Puma History.md: 7.2.1 bounds/anchors PROXY v1 parsing and
parses it once per connection. Puma 7 requires Ruby >=3.0, lowercases response
headers, changes default keepalive limits/timeouts, defaults cluster preloading
on, and renames callback hooks. Existing single-process configuration remains
the tested mode. Cluster mode and its database reconnect hook are not approved
by the single-process fixture.

## Executable transport contract

From the repository root:

```sh
ruby scripts/isolated_bundle.rb exec ruby tests/puma_http_test.rb
```

CI runs `bundle exec ruby tests/puma_http_test.rb`. Uses temporary Rack fixtures,
real subprocesses and loopback sockets. It never boots app/config.ru, loads dotenv,
selects DB/Redis, or queues startup refreshes. Test data/session secret are fixtures.

Three launch modes:

1. Rackup with the deployed command shape (explicit Puma handler, temporary Rack
   app, loopback port, test environment): cookie/token, valid/invalid CSRF, request
   body, persistent requests, malformed Content-Length, SIGINT shutdown.
2. Direct Puma CLI with repository config, temporary Rack app, staging log mode,
   zero workers and two threads: same HTTP checks plus SIGTERM shutdown.
3. Isolated PROXY v1 configuration (not application config): valid initial header,
   repeated header rejected on keepalive, oversized line rejected/connection closed,
   SIGTERM shutdown.

All 19 checks passed locally, including a gated in-flight fixture request that
completes after TERM while the server waits. This is a bounded regression, not exhaustive malformed
HTTP fuzzing, an RSS/load test, TLS acceptance or full-application browser evidence.
The test briefly reserves an OS-assigned port before subprocess bind; there is a
small competing-process port-allocation race. Each subprocess has bounded startup,
socket reads and shutdown with forced cleanup on failure.

## Shutdown limitation — do not hide this

Rackup 2.2.1 installs SIGINT handling; its Puma handler does not install the Puma
CLI's SIGTERM traps. The initial fixture SIGTERM check did not terminate gracefully.
The test now explicitly covers Rackup SIGINT, **not Rackup SIGTERM**. The Render
blueprint still uses rackup: do not infer platform termination safety from this test.

The direct Puma CLI logs graceful stopping on TERM and, by default, re-raises
SignalException afterward. The contract accepts successful exit or termination by
that exact signal accompanied by the graceful-stop log, not arbitrary failure.
The gated fixture drain is now tested; it does not establish platform deadlines or
cluster/streaming-request drain behavior.

## Actual-app middleware and drain acceptance

Latest extension passes **19 checks** (the twelve-check baseline below remains
historical). Seven new assertions cover missing-CSRF rejection on `/like`, repeated
true/false desired-state requests with exact counts and invalid boolean rejection.
Uses actual HTTP/Redis-session stack, not browser-button events. Random fixture
like metadata/activity are deleted at exit along with the user; independent local
read-back confirmed zero matching users, stats and activity. No concurrent HTTP
session-write claim; pooled DB concurrency has separate backend tests.

Opt-in command (start your disposable Redis on 16379 first; no worker process):

```sh
DATABASE_URL=postgresql://localhost/meme_explorer_ack_browser_test \
REDIS_URL=redis://127.0.0.1:16379/0 \
ruby scripts/isolated_bundle.rb exec ruby tests/app_server_test.rb
```

The database must already have the application schema. This test refuses nonlocal
or non-test-named databases and Redis ports other than 16379. Do not point it at
valuable local data merely because the name passes the guard. It creates/deletes
one random fixture user and writes test sessions/viewer metadata; it never truncates
the database. An externally killed process may leave a fixture account requiring
private cleanup. A negative nonlocal-URL guard test exited 1 before app boot.

The wrapper evaluates actual config.ru with its Redis session, SessionValidator,
AuthorizationMiddleware, compression and app stack. Dotenv loading is bypassed,
the child receives an allowlisted environment, outbound Ruby HTTP is denied by
WebMock, Sidekiq is faked and media supply uses local fixtures. Startup refreshes
cannot execute provider work through this harness. No feed flag override.

Twelve local checks passed: login token/Redis cookie; missing CSRF rejection; email
authentication; rotated-session profile; favorites alias; retired taste page;
viewer local-media markup; old-token rejection; current-token logout; profile
protection afterward; real health response after TERM; app/analytics shutdown.
A deterministic wrapper gate holds a health request before entering the actual
stack, signals the direct Puma CLI, then releases it after graceful-stop logging.
This proves that queued in-flight request can traverse the actual stack after TERM,
not drain of every application task, production timeout behavior or browser media.
Fixture user count was zero after completion. Temporary Redis stopped afterward.

This test intentionally uses direct Puma without repository server config, keeping
test logs private and binding loopback. Repository server config is covered by the
separate transport test. Render Rackup/platform TERM remains unaccepted. The actual
app test is opt-in, not added to CI until its isolated service provisioning and
database ownership are explicitly configured.

## Required before deployment approval

1. Run hosted Linux test/security gates on the candidate revision.
2. Boot the actual app/middleware with isolated staging DB/Redis, provider network
   safeguards and disposable users; verify auth/session/CSRF, media and exact actions.
3. Test real in-flight request drain and platform termination. Decide explicitly
   whether to keep rackup with supported termination behavior or adopt direct Puma;
   compare threads/binds/timeouts and resource budgets before changing start commands.
4. If cluster deployment is desired, separately validate preloading, DB reconnects,
   Redis/thread ownership, worker shutdown and startup jobs. Do not enable it casually.
5. Record web/worker revisions, observation window, rollback and operator approval.

Rollback: revert the Gemfile/lockfile/Puma hook slice together to the last accepted
candidate, reinstall with frozen dependencies, rebuild and redeploy through approved
operations. That older Puma has known advisories; rollback is incident mitigation,
not security clearance. Preserve other unrelated product changes.

Fresh local `bundler-audit check --update` reports no known vulnerabilities against
database revision `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`. This is dependency
clearance for that scan, not proof the app is secure or ready to deploy.