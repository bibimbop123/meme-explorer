# Metrics accuracy audit

Local implementation; not committed or deployed.

## Findings and corrections

- HTML, JSON and CSV previously used different aggregation/filter logic. They now
  share MetricsReport and reject unknown periods with 400.
- Filtering meme_stats.updated_at and summing lifetime counters does not measure
  activity within a historical window. Rolling reports and rankings now aggregate
  timestamped activity, excluding future events and using one captured cutoff.
- Charts previously assigned lifetime totals to the last update date. Charts now
  count recorded view/like events in UTC and include both partial edge buckets.
- All-time cards retain cumulative stored totals; all-time chart explicitly shows
  only the last 30 days of recorded events. Historical logs cannot reconstruct
  activity never collected, and current likes are not lifetime like actions.
- Registered accounts, saved entries and zero-count inventory are current/global
  snapshots, explicitly labeled rather than pretending the period filters them.
- Period likes mean gross like actions, not net likes after unlikes. The ratio is
  labeled likes/views, not unique-user engagement; no views yields N/A.
- Selection latency is a recent rolling sample, independent of period. Retention
  retains its separate 14-day scope; account-day activity span is not session length.
- DB failure now returns 503 instead of silently showing zeroes or substituting
  lifetime counters. Reports are no-store. Ranking text is HTML escaped; unsafe
  raw media-link interpolation was removed.

## Validation and limitations

Backend: 1,298 examples, zero failures, seven pending; 77.31% coverage, exit 0.
Frontend: 143 passing. Syntax/whitespace checks passed. An intermediate patch
damaged the module header and failed at load time; restored and full suite rerun.

Tests cover all four periods, aged/future fixtures, HTML/JSON/CSV parity,
partial-hour accounting, invalid input, unavailable DB and stored-text escaping.
Exact start/end inclusion and just-outside exclusion tested for all rolling windows.
Empty-window rendering keeps global snapshots and zero-event chart visible.
Rankings use the same recognized activity types as summaries.

Isolated headless Chrome: actual local login, all four desktop period pages show
correct active filter, report source, chart canvas and global snapshots without
document-wide horizontal overflow. At mobile 390x844, no document-wide overflow.
Dedicated local DB/Redis, temporary Rack fixture wrapper, external HTTP blocked;
production untouched and temporary services stopped. Chart.js CDN intentionally
blocked, so actual chart drawing was NOT verified. No production database audit.
Stored activity can be incomplete or reflect historical tracking behavior; labels
do not certify source completeness. Retention query methodology was not rewritten.
No new schema/index migration or load-performance claim is included.

Chart resilience follow-up: exact UTC bucket table is server-rendered and usable
without JavaScript/CDN; status explains unavailable/loading chart. Canvas has an
accessible label. Straight lines and integer ticks avoid implying fractional event
counts. Route tests verify table totals match JSON chart values for all periods.
Local Chrome with CDN blocked verifies visible fallback and table, then a Chart
constructor double executes the actual rendered script and confirms integer ticks,
zero smoothing, matching label/table counts and status hiding on construction.
Observed buckets: all/30d 31, 7d 8, 24h 25 (partial edge buckets included).
This verifies script/configuration, NOT real Chart.js canvas drawing. Mobile
document-width check still passes. Temporary browser services stopped.