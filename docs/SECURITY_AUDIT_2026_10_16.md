# Release security-audit diagnosis

## Current checkpoint — 2026-10-17

**Superseding Puma checkpoint:** local Puma 7.2.1 upgrade now clears the fresh
dependency audit (zero findings, exit 0). [Transport acceptance](PUMA_7_ACCEPTANCE.md)
records 17 passing real-socket checks and the unresolved Rackup SIGTERM/platform
acceptance limitation. Hosted CI and actual-app staging acceptance remain required;
this is not release approval. The paragraph below describes the preceding batch.

Release security gate still blocked, now by **Puma 6.6.1 only** in the fresh
standalone advisory scan. The original baseline and first-batch notes below are
historical, not the current dependency inventory. No advisory ignores added.

Second local batch (Gemfile constraints unchanged):

| Gem | Previous | Updated |
| --- | --- | --- |
| activesupport | 7.2.3 | 7.2.4 |
| faraday | 2.14.0 | 2.14.4 |
| httparty | 0.23.2 | 0.24.3 |
| json | 2.15.2 | 2.21.2 |
| jwt | 3.1.2 | 3.3.0 |
| oauth2 | 2.0.17 | 2.0.25 |
| sqlite3 (development only) | 2.7.4 | 2.10.0 |

Conservative scoped updates used isolated Bundler, not shared RVM gems. OAuth2
requires new transitive anonymous_loader/auth-sanitizer and updates snaky_hash /
version_gem; those resolved changes are retained and visible in the lockfile.
Registry Ruby requirements fit pinned Ruby 3.2.1. SQLite native in-memory
create/insert/read/close passed on macOS arm64; Linux CI remains required.

The first six upgrades plus route repair passed 1,304 backend examples, zero
failures, seven pending, 77.43% coverage. Frontend: 148 passing; build, native
diagnostics and standalone CSRF contract passed. SQLite was then updated as a
separate slice; final full-suite evidence is recorded in the acceptance ledger.

Fresh post-SQLite audit exits 1 for two Puma PROXY protocol advisories: v1 parser
remote memory exhaustion and repeated headers on persistent connections. Reported
remedies are ~>7.2.1 or >=8.0.2; Gemfile ~>6.0 prevents these. Assess actual proxy
configuration/exposure but do not equate unconfirmed exposure with clearance.
Next slice must test major-version compatibility, real HTTP serving, malformed
request boundaries, boot/shutdown, configured start commands and rollback.

No hosted CI, actual provider OAuth, deployed server acceptance, credential
rotation or production changes claimed. Raw temporary audit output:
`/tmp/meme-roadmap-final-security.log`. Research and browser acceptance stay open.

## Historical baseline and first batch

Status: **release blocked; dependencies not remediated**.
Update: the first four-gem patch batch below is remediated locally; remaining
dependencies still block release. The table records the original audit baseline.
Application/lockfile inspected at `67661da`; CI run 38951948445 failed at security
audit while its test job passed. Public annotations only report exit 1, so the
exact hosted stderr/cause was not established.

## Reproduction

Local bundled invocation fails: bundler-audit is not in Gemfile/lockfile. CI installs
it globally but used `bundle audit check --update`. Workflow now installs standalone
bundler-audit 0.9.3 and invokes `bundler-audit check --update`; not run on hosted CI.
No audit ignores, continue-on-error or reduced coverage added.

Installed tool in disposable `/tmp/meme-explorer-audit-tools`, outside shared RVM
and project dependency directories. Standalone check --update completes with exit 1
and reports vulnerabilities using the fetched ruby-advisory-db. It is a current
local database result, not proof of which advisories caused the earlier hosted run.
Raw local report: `/tmp/meme-security-audit.log`; tool version 0.9.3.

## Upgrade queue from tool output

These are reported minimum constraints, **not installed or compatibility-approved**.
Check primary advisory details, platform variants, Ruby compatibility and a fresh
audit before choosing final versions. Multiple findings can affect the same gem.

| Locked gem/version | Reported remedial version on relevant line |
| --- | --- |
| activesupport 7.2.3 | 7.2.3.1 or newer compatible patched 7.2 |
| bcrypt 3.1.20 | >= 3.1.22 |
| concurrent-ruby 1.3.5 | >= 1.3.7 |
| faraday 2.14.0 | >= 2.14.3 for all reported findings |
| httparty 0.23.2 | >= 0.24.0 |
| json 2.15.2 | >= 2.19.9 for all reported findings |
| jwt 3.1.2 | >= 3.2.0 on 3.x |
| oauth2 2.0.17 | >= 2.0.22 |
| puma 6.6.1 | ~> 7.2.1 or >= 8.0.2; current Gemfile ~> 6.0 blocks this |
| rack 3.2.4 | >= 3.2.6 for all reported findings |
| rack-session 2.1.1 | >= 2.1.2 |
| sqlite3 2.7.4 | >= 2.9.6 for all reported findings; development-only is still audited |

Examples for primary review: Rack GHSA-vgpv-f759-9wx3, rack-session
GHSA-33qg-7wpp-89cq, HTTParty GHSA-hm5p-x4rq-38w4, and Puma
GHSA-qpgp-93vx-g8v8 / GHSA-2vqw-3mp8-cgmx. Do not infer production exploitability
or severity solely from the inventory; assess usage and advisory conditions.

## Required next work

1. Review advisory details and choose supported Ruby-compatible patch versions.
2. Update locked dependencies in reviewed batches, with isolated installs/native
   checks. Handle Puma major-version/server compatibility separately and test boot,
   request/session behavior, shutdown and Render start commands.
3. Run security audit, frontend/build, full backend/coverage and real auth/session/
   HTTP/media regression checks. Do not remove SQLite or ignore advisories merely
   to make the audit green without reviewing actual development-tool usage.
4. Pin the resulting application SHA; obtain fresh hosted test/security success.
   Prior local green tests do not validate upgraded dependencies.

## First remediation batch — locally validated, uncommitted

Only four lockfile entries changed; Gemfile constraints unchanged:
Rack 3.2.4 → 3.2.7, rack-session 2.1.1 → 2.1.2, BCrypt 3.1.20 → 3.1.22,
concurrent-ruby 1.3.5 → 1.3.8. Registry Ruby requirements checked before isolated
conservative patch update; shared RVM gems untouched.

Repeat standalone audit against the fetched database no longer reports these four
gems. It still exits 1 for activesupport, faraday, httparty, json, jwt, oauth2, puma
and sqlite3. No advisory ignores or gate bypass. Report:
`/tmp/meme-security-batch1-audit.log`. Database revision used for diagnosis:
`a6847b0651a702488f5844081e848dd1ec9dbf1d`; newer databases may add findings.

Validation: isolated Ruby/native checks and CSRF contract pass; 119 frontend tests
and Vite build pass. Full backend: **1044 examples, zero failures, seven pending**,
56.06s; **74.12% coverage (4571/6167)**, gates pass, exit 0. No actual provider OAuth,
deployed server acceptance or fresh hosted CI claimed. Release candidate must be
repinned after review/commit; 67661da remains the historical pre-upgrade candidate.

Nothing pushed, deployed or changed in production. Next batches: compatible
ActiveSupport/HTTP/auth/JSON patches, SQLite platform/native review, and a separately
reviewed Puma major upgrade. Feed audit/user research remains a parallel task.