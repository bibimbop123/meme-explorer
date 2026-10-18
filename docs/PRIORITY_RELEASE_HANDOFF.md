# Immediate priority handoff

## Current decision

Do not expand ranking or enable feed flags before baseline and release acceptance.
Local correctness checks are not deployment approval or satisfaction evidence.

## Engineering gates

- Search fallback supports titles/community names, sparse-source supplementation,
  literal wildcard handling and URL/file identity; service and real-route regressions.
- CI now rejects tracked `public/dist` drift after build. Local rebuild is identical.
- Last local dependency scan: no known findings. Repeat hosted security/test gates
  on the committed candidate; local results do not prove hosted success.
- Before applying any deployment command change, validate Rackup SIGTERM/platform
  drain and compare direct Puma binds/threads/timeouts. See PUMA_7_ACCEPTANCE.md.
- No permission inferred to push, deploy, enable feed flags or rotate credentials.

## Operator-owned release checklist

1. Record candidate commit and previous web/worker revisions privately.
2. Run hosted CI on that exact revision through the approved process.
3. Privately review tracked environment/database artifacts, identify credential
   owners, rotate live exposed values, and plan history cleanup if needed. Never
   paste credentials into the ledger or commit private exports.
4. Complete isolated staging/provider/network safeguards, shutdown/drain and
   rollback acceptance. Record failures and stop conditions before rollout.
5. Finish actual zoom, screen-reader/device and ad-overlay checks. Local CDP
   assertions are narrower evidence; do not mark those manual checks passed.

## Product/research work that must start next

Assign a researcher/reviewer and an engineering contact. Use
[CONTENT_BASELINE_WORKSHEET.md](CONTENT_BASELINE_WORKSHEET.md) and
[CONTENT_AUDIT_RUNBOOK.md](CONTENT_AUDIT_RUNBOOK.md); keep collected data private.

- Observe 100 displayed selections across two windows and all four joint
  guest/returning × mobile/desktop groups. Double-review 20 selections.
- Observe 5–8 consented intended users finding worthwhile content, sharing,
  recovering, saving and changing topic. Do not require sending private messages.
- Review three ordinary supply cycles; do not force jobs or raise provider budgets.
- Run bounded offline summary; review unknowns and missing sample groups. Count
  completion is not research acceptance. No observations have been collected here.
- Rank three problems by observed severity/frequency/confidence/effort, choose one
  experiment, and predeclare success/guardrails/stop/rollback before implementation.

## Next implementation decision

If steering is the observed dominant problem, implement one reversible source/topic
control with clear persistence, Undo/reset and honest exhaustion. If freshness,
visual repetition or unreadability dominates, choose that intervention instead.
Do not ship all simultaneously or treat Next as negative feedback.

Scores remain provisional until reviewed content, actual user journeys and sustained
deployment evidence justify reassessment. The acceptance ledger holds run details.