# Controlled release packet — October 16, 2026

**Status: preparation only; NOT approved, pushed or deployed by this workflow.**
Application candidate: `67661da` on `checkpoint/reliability-exact-meme-sharing`.
If candidate code/config changes, repeat relevant validation and pin the new SHA.
**Candidate superseded by uncommitted dependency/CI changes:** do not deploy
67661da or treat its hosted test result as validation of the new lockfile. First
patch batch passes local regressions but audit still fails; repin after remediation.

## Evidence and unknowns

- Latest full local backend: 1,044 examples, zero failures, seven pending;
  74.09% coverage, coverage gates pass, exit 0. Not hosted CI evidence.
- Release preparation reran isolated Ruby/native-dependency checks, Vite build,
  all 119 frontend tests and whitespace checks successfully.
- Read-only local test-schema check finds meme_catalog, meme_impressions and
  meme_activity_log. This verifies relation presence, not column/index compatibility
  or production schema. Production migrations were previously operator-reported
  applied, but current deployed schema was not inspected here.
- Cached origin/checkpoint ref equals candidate (0/0); cached origin/main is 32
  commits behind candidate. No fetch/push performed: cached refs do not establish
  current GitHub state, mergeability, deployment SHA or CI success.
- Production origin: https://meme-explorer.onrender.com. Sample exact-page social
  metadata is missing. Root cause remains unconfirmed; see production evidence.

## Approval gates — assign a named owner to each

### Fresh public verification — 2026-10-16 19:09 UTC

- Exact candidate SHA: `67661dafddfa887fa1ddd8567b5d3fceca73006a`.
- [GitHub run 38951948445](https://github.com/bibimbop123/meme-explorer/actions/runs/38951948445)
  completed with failure: test job passed; security job failed at **Run security
  audit**. Cause/advisory details not retrieved. **Release blocked** until diagnosed,
  remediated and green on the resulting exact candidate. No workflow triggered.
  Local follow-up reproduced a bundled-tool loading issue and real standalone audit
  findings; see SECURITY_AUDIT_2026_10_16.md. CI invocation corrected locally only;
  dependency remediation and new hosted green run remain required.
- Short SHA API query returned no runs; full-SHA query returned the run above.
  Use full SHAs for verification rather than interpreting the short query as no CI.
- Public exact recipient still returns 200 without canonical/og:url/og:image.
  Live PUBLIC_ORIGIN and deployed commit remain unknown. Blueprint declaration
  verified locally but is not evidence of live configuration.
- Isolated Ruby/native dependency checks and Blueprint parse/setting check pass.
  No push, deployment, environment change or private infrastructure access.

Feed-audit preparation: `FEED_AUDIT_CAPTURE.csv` is an empty header-only worksheet,
not sampled production data. Pair with FEED_EXPERIENCE_AUDIT.md; assign a named
facilitator, agree consent/retention and recruit 5–8 participants before sessions.

- [ ] Reviewer: review accumulated diff, dependencies, security and migration/config
  compatibility against the actual deployed commit, not assumed main or bundle hash.
- [ ] Operator: record actual deployed web/worker SHAs, environment and rollback SHA.
- [ ] Security/operator: rotate previously exposed credentials privately; update
  dependent services coherently. Record completion without values; assess session
  invalidation if session secrets rotate. Do not paste secrets into tickets/logs.
- [ ] CI owner: verify fresh GitHub state and green test/security jobs on the exact
  candidate SHA. Workflow supports checkpoint pushes and manual dispatch; neither
  is authorized by this document. Do not disable failing security/coverage gates.
- [ ] DB operator: run the read-only viewer schema check in the intended environment
  and review required columns/indexes against migrations. Never apply the whole
  postgres_schema.sql to production. Do not run --apply unless a migration is
  missing, reviewed, backed up and separately approved.
- [ ] Operator: confirm PUBLIC_ORIGIN is the approved HTTPS origin, Reddit callback
  matches it, and web/worker use the intended database/Redis. Never print URLs with
  credentials. Blueprint declarations do not prove dashboard values.
- [ ] QA/product: approve scoped acceptance. Physical mobile, screen reader, real
  OAuth and platform crawler checks remain open. Document exclusions explicitly;
  do not imply full acceptance from local headless fixtures.
- [ ] Release owner: explicitly approve staging/canary and production changes with
  monitoring, stop rules, rollback owner and a communication plan.

## Read-only operator commands

Run inside the approved application's bundled environment with existing environment
variables; do not type credentials into shell history. From the repository root:

```sh
bundle exec ruby scripts/check_viewer_schema.rb
bundle exec ruby scripts/check_pool_inventory.rb
```

The inventory report is fixed-key, non-atomic metadata sampling; matching samples
do not prove shared Redis or unique artwork. The schema command without --apply
does not apply migrations. Review output before sharing; never include auth headers.

## Approved rollout sequence (not executed)

1. Preserve database backup/recovery readiness, prior deploy identifiers and relevant
   configuration history. Do not purge working Redis pools, catalog or impressions.
2. Validate the candidate in staging with representative media and disposable users.
   Build assets **before** backend boot: bundle fingerprint is calculated at boot.
3. Apply only separately approved additive migrations/config changes. Verify deployed
   PUBLIC_ORIGIN rather than weakening Host trust. Environment edits may restart
   services; use the release window/rollback procedure, not an unreviewed quick edit.
4. Deploy web/worker through the approved platform process at the pinned candidate.
   Confirm both boot correctly and the worker consumes default jobs. Free-plan or
   platform constraints must be verified; Blueprint presence is not worker evidence.
5. Smoke test exact sharing, guest/auth Save continuation, profile search/Likes,
   Remove/Undo/reload, private auth headers and media recovery. Inspect one exact
   canonical/og:url/og:image and fetch the preview; test real platform rendering.
6. Observe at least three **normal** maintenance cycles. Record job start/end,
   duration/lease TTL, OAuth outcome, candidate rejection, unique additions,
   publication conflicts and subsequent retained counts. Do not force fetch storms.
7. Run the consecutive-feed audit and user tasks in FEED_EXPERIENCE_AUDIT.md.
   Release success does not establish humor, variety or a score increase.

## Stop and rollback

- Stop rollout on wrong-content actions, favorite loss, account-data exposure,
  migration incompatibility, auth failures or unusable media/navigation. Define
  numerical error/latency/source-failure budgets from baseline before approval.
- Operator rolls web/worker back coherently to the recorded known-good version;
  verify its compatibility with retained additive schema and config first. Do not
  automatically reverse/drop catalog/impression tables: existing shared links depend
  on persisted identities. No automatic downgrade migration is supplied here.
- Do not delete active leases or flush Redis to make a rollback look healthy. A
  killed maintenance job's two-hour lease can delay replenishment; inspect ownership/
  TTL and follow the incident procedure rather than deleting a live owner's lease.
- If PUBLIC_ORIGIN alone is wrong, use separately approved config correction and
  retest; code rollback need not be the answer. Preserve evidence without secrets.
- Verify user journeys and inventory again after rollback. An ambiguous Redis EXEC
  disconnect or runtime command error may require investigation; transaction use is
  not rollback safety. Document incident, outcome and outstanding acceptance gaps.