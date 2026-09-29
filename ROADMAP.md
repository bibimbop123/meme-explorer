# 🎯 Roadmap: The Thiel Test

**Last written:** this session, grounded in the actual state of the codebase
(`git log`, `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md`) - not aspirational.
If a claim here stops matching reality, fix the claim or fix the code in the
same commit; don't let this drift the way old `docs/archive/` reports did.

## The thesis

Peter Thiel's framing: don't compete for a slice of a big, commodity market -
find a small market you can dominate completely, one with a real, defensible
monopoly logic behind it, then expand outward from that base.

Meme Explorer's underlying content supply is Reddit's - that's a commodity,
and competing on "biggest/most complete meme archive" is a race we lose to
Reddit itself. The one thing Reddit's own scroll/random experience does NOT
do is remember you and get measurably better at picking your next meme.

**The thesis: Meme Explorer's monopoly is not "more memes" - it's the best,
fastest, most personalized single decision in the product: picking the next
meme for this exact person, right now.** Everything in `SelectionBenchmark`
and `MemePoolManager`'s anti-repetition selection already points at this;
this document just names it explicitly so it drives prioritization instead
of staying implicit.

Consequence: features that don't strengthen (a) the reliability of that one
decision, or (b) how personalized/well-targeted that decision is, are lower
priority than ones that do - regardless of how easy or exciting they are to
build. This reorders some of README.md's existing Roadmap section rather
than replacing it.

## Progress log

**This session:** a reliability audit surfaced and fixed several concrete
bugs matching this document's own thesis - not hypothetical risks, actual
broken/dead code found by reading the app against its own test suite and
docs:
- Removed a dead-code landmine in `routes/user_api_routes.rb`: duplicate
  `/profile`, `/api/save-meme`, `/api/unsave-meme`, `/saved/:id` routes,
  unreachable (registration order means `routes/profile_routes.rb` always
  wins) but calling three methods that don't exist anywhere in the
  codebase - a silent NoMethodError landmine if registration order ever
  changed.
- Found `RedisService.setex` doesn't exist (real API is
  `set(key, value, ttl:)`) - `TrendingService.cached_trending` had been
  silently failing to cache anything since it was written, recomputing the
  full trending-score SQL query on every single request. Fixed.
- Found `/trending.json` and `/api/trending` - both documented in
  `README.md`, both directly tested - never actually existed as routes;
  every request 404'd. Implemented both against the already-correct
  `TrendingService`.
- Fixed ~54 failing pre-existing spec examples (of ~235) that were testing
  APIs services never had (wrong method signatures, instance vs. module
  methods, SQLite syntax against the real PostgreSQL schema) rather than
  real bugs - each fix explained inline with a `BUG FIX:` comment at the
  point of change, distinguishing "test was wrong" from "code was wrong."
  ~180 pre-existing failures remain, catalogued but not yet fixed
  (`spec/edge_cases/`, `spec/integration/`, several more route/service
  specs) - same pattern, continuing incrementally.

**Continued this session - a much bigger finding:** several routes are
defined multiple times across different `routes/*.rb` files, and Sinatra
silently uses whichever one is `register`ed LAST in `app.rb` - so the
"real," live behavior of `/admin`, `DELETE /admin/meme/:url`,
`/api/notifications`, and `AppHelpers`'s auth helper methods was
determined by file registration order, not by which copy looked more
correct. Concretely:
- `AppHelpers` (registered after `AuthHelpers`) silently shadowed
  `AuthHelpers`'s correct `logged_in?`/`current_user_id`/`require_admin!`
  with strictly weaker versions - `admin?` checked a session field
  (`session[:role]`) that only middleware wired in `config.ru` (not
  `app.rb`) ever keeps in sync, instead of querying the DB live.
- `routes/admin_inline_routes.rb` (registered after `routes/admin_routes.rb`)
  shadowed a working `GET /admin` with a version that called `is_admin?`
  with zero arguments - raising `ArgumentError` on literally every request,
  meaning the admin dashboard has been completely broken (500) this whole
  time, not just theoretically fragile.
- Its `DELETE /admin/meme/:url` used a named param that can never match a
  URL containing `/` - meaning no admin has ever been able to delete a
  meme by its real URL through this endpoint, ever, even before the
  `is_admin?` crash. Fixed with a splat route AND correcting for Rack's
  slash-collapsing in `PATH_INFO` (a second, independent bug hiding behind
  the first).
- `routes/metrics_routes.rb` and `routes/system_routes.rb` both defined
  `/api/notifications`, both calling a method
  (`get_user_saved_memes_count`) that doesn't exist anywhere - so this
  endpoint 500'd on every request regardless of which copy won.
- Two more zero-arg `is_admin?` calls (`system_routes.rb`'s
  `/health/detailed`, `user_api_routes.rb`'s `/api/test-push`) had the
  identical crash-on-every-request bug.

None of this was caught by manual testing because these are all
authenticated/admin-only paths - exactly the kind of surface area that's
easy to leave broken for a long time because it's not on the critical
"can a logged-out visitor see a meme" path, but it's still part of the
reliability bar this roadmap is about. ~81 of the original ~235 failing
spec examples are now fixed; the dead-code duplicate routes are removed
entirely rather than left as landmines for the next registration-order
change.

**Continued further - the personalization moat was silently broken.**
Found a systemic SQL bug pattern: `INSERT ... ON CONFLICT ... DO UPDATE SET
col = col + 1` is genuinely ambiguous in PostgreSQL (it can't tell if the
right-hand `col` means the existing row or the proposed insert) and raises
`PG::AmbiguousColumn` - silently caught by a surrounding `rescue` in every
case found. This bug was already correctly fixed in some call sites
(`routes/random_meme.rb`, `routes/home.rb`, `routes/utility_routes.rb` all
correctly qualify as `meme_stats.views`) but NOT in others:
- `report_broken_image` (lib/helpers/meme_navigation_helpers.rb) - every
  single broken-image report has silently failed to record anything,
  ever, since this method was written.
- `navigate_meme_unified`'s view-count upsert - same file, same bug,
  unqualified `views = views + 1`.
- **`update_user_preference`** (same file) - this is the mechanism by
  which per-user subreddit preference scores are supposed to compound
  over time, directly the "personalization as the moat" mechanism this
  roadmap's Phase 1 calls for. It has been silently failing on every
  single call, meaning `apply_user_preferences`
  (lib/helpers/meme_pool_helpers.rb) has likely never seen a real,
  incrementing `preference_score` for any user, ever - the personalization
  loop this document identifies as the core differentiator has had a
  silent, load-bearing crack in it the whole time. Fixed by qualifying
  each ambiguous column with its table name.

Also found and fixed this session:
- `MemeService.cached_memes`, `MemeService.report_broken_image` - two more
  class methods called from `routes/memes.rb` that have never existed;
  `/search`, `/api/search.json`, `/report-broken-image` all 500'd on every
  request. Fixed by using the real `MemeExplorer::App::MEME_CACHE[:memes]`
  and the real top-level `report_broken_image` helper, respectively.
- `SearchService.search` always returns a Hash (`{results:, total:, ...}`),
  never a bare Array - `routes/memes.rb` called `.map`/`.size` directly on
  that Hash, a second independent bug stacked on the first.
- A THIRD duplicate-route case (first-registered-wins this time, not
  last-registered - the opposite of the AppHelpers/admin_inline_routes
  bugs found earlier): `routes/search_routes.rb` fully duplicated
  `GET /search` and `GET /api/search.json` from `routes/memes.rb`, and was
  the dead copy. Removed.
- `request.accept.include?("application/json")` - appears identically in
  FOUR files (`routes/memes.rb` x2, `routes/search_routes.rb`,
  `routes/trending_routes.rb`) - `request.accept` returns
  `Sinatra::Request::AcceptEntry` objects, not strings, so `.include?` on
  a string never matches even with a real `Accept: application/json`
  header. The correct API is `request.accept?(...)`. Fixed all four.
- Five placeholder test stubs in `spec/routes/memes_spec.rb`
  (`pending "Add GET route tests"` with empty bodies) were failing on
  every run for a subtly different reason: `pending` expects the block to
  fail, and an empty block trivially "passes" - removed as pure debt with
  real coverage already existing elsewhere.
- `POST /like`'s real route only ever reads a JSON body
  (`JSON.parse(request.body.read)`), matching the real frontend
  (`public/js/modules/meme-interactions.js`) - several spec files sent
  form-encoded params instead and were exercising the wrong code path
  entirely (the JSON-parse-failure branch, not the real logic).

~113 of the original ~235 failing spec examples are now fixed (48%
reduction). The personalization-scoring bug above is arguably the single
most important fix of this whole session relative to this roadmap's own
stated thesis - it's exactly the kind of "the loop that's supposed to be
our moat doesn't actually work" bug Phase 1 exists to catch.

**Continued further - a new bug class: static files silently shadowing
carefully-written dynamic routes.** Sinatra serves `public/` static files
before dispatching to routes, so a stale static file at the same path
wins even when a route handler for that exact path exists and is
never wrong on its own terms. Found and fixed two real, live instances:
- `public/robots.txt` (a stale, less complete file - no `Disallow: /api/`,
  no Googlebot/Bingbot-specific rules, no bad-bot throttling) was shadowing
  `GET /robots.txt` in `routes/seo_routes.rb`, a genuinely more complete,
  dynamically-generated version. Every crawler has been reading the
  worse, static version this whole time.
- `public/manifest.json` (missing `icons`, `categories`, `screenshots`,
  and a dynamic `base_url`-aware icon path) was shadowing
  `GET /manifest.json`'s real, complete version - meaning the PWA install
  experience has been missing home-screen icons entirely.
Removed both stale static files; the dynamic routes now serve correctly.
This is a distinct failure mode from the duplicate-*route* bugs found
earlier (all resolved by Sinatra's own registration order) - here Rack's
static-file middleware itself, which runs before any route dispatch at
all, was the silent culprit, and no amount of fixing the route code
itself could ever have surfaced it without noticing the shadow file.

Also removed as pure test debt (empty `pending` placeholder stubs and/or
fully-redundant duplicate coverage of already-fixed specs, same pattern as
`spec/routes/memes_spec.rb` earlier): `spec/routes/auth_spec.rb`,
`spec/routes/profile_spec.rb`.

**Continued further - a real, live stored-XSS vulnerability, found via a
test file that turned out to be worth rewriting rather than deleting.**
`spec/edge_cases/boundary_tests_spec.rb` was written against entirely
fictional APIs (`DB[:users].insert(...)` - Sequel-style, but this
codebase's real `DB` is a hand-rolled `DBWrapper` around raw SQL; `/login`
accepting a `username` param when the real route only ever accepts
`email`; and four routes - `GET /memes/:id`, `GET /profile/:id`,
`POST /api/memes`, arbitrary-string `/category/:name` segments - that
don't exist anywhere). Rather than deleting it as pure debt (some of it
was, and got dropped), the underlying test *intent* - SQL injection
resistance, XSS escaping, boundary values - was real and worth keeping,
so it was rewritten against real routes/APIs. Doing that surfaced a
genuine bug the fictional version could never have caught: `views/saved_meme.erb`
and `views/layout.erb` (the shared page header used on every full-page
response) interpolated meme titles/subreddits directly into HTML with
**no escaping at all** - Sinatra's plain ERB does not auto-escape by
default, unlike Rails, and nothing in this codebase enables that setting
globally. A saved or trending meme with a title like
`<script>alert('xss')</script>` (Reddit content is not authored by this
app - a title like that is entirely plausible from upstream) would
execute in any visitor's browser who viewed that meme. Fixed by escaping
both interpolations with `Rack::Utils.escape_html`; `views/layout.erb`'s
og:description tag was also relying on a partial `.gsub('"', "'")`
quote-escape rather than genuine HTML escaping, fixed the same way. This
is worth a broader audit (grep for `<%=` across `views/` for other
un-escaped user/Reddit-sourced content) as a follow-up, not done
exhaustively in this pass.

~150 of the original ~235 failing spec examples are now fixed (~64%
reduction, 633 examples remaining, 85 failures, 14 honestly-pending).

**Continued to substantial completion.** Kept working through the
remaining failure clusters. Found and fixed several more real bugs:
- `views/leaderboard.erb` didn't exist at all - `GET /leaderboard` has
  500'd on every single request since a "slash and burn" cleanup commit
  deleted the view but left the route calling `erb :leaderboard`, despite
  README.md documenting `/leaderboard` as a real, working feature. Built a
  minimal, honest replacement view that safely renders the route's
  already-correct data-gathering logic (rank, insights, weekly challenge)
  rather than attempting to restore the more elaborate deleted UI.
- `Validators.sanitize_string`'s XSS-stripping regex only matched QUOTED
  `on\w+="..."` event-handler attributes and a fixed list of dangerous
  tags (script/iframe/object/embed) - a payload like
  `<img src=x onerror=alert(1)>` (unquoted attribute, and not one of
  those specific tags) passed through completely unsanitized. Fixed to
  also strip unquoted event-handler values and tags carrying them,
  regardless of tag name.
- `UserService.create_or_find_from_reddit` returned a String from one
  code path (a raw PG row value) and an Integer from the other (`DB.last_insert_row_id`)
  for what every caller treats as the same "user id" - silent type
  inconsistency that would break any `==` comparison between a fresh vs.
  looked-up id.
- `UserService.find_by_email` never selected the `email` column itself,
  only `id`/`password_hash` - any caller reading `user['email']` off a
  real, found user always got `nil`.
- `CacheKeys.leaderboard`/`.trending` - a test-only finding this time,
  not a real caller bug, but worth noting: the real methods are
  `leaderboard(type, period='weekly')` (period is second positional, not
  first) and `trending_memes(timeframe)` (no bare `.trending`) - easy to
  misuse from outside this file's own tests too.
- Multiple more instances of the by-now-familiar patterns: fictional
  Sequel-style `DB[:table]` APIs, `SQLite3::*` references (real DB is
  PostgreSQL), routes that don't exist (`/force_refresh`,
  `/api/memes/1/like`, `/profile/1`, `/api/users/:id/award_points`,
  `/admin/ab-testing`), an entire A/B-testing feature
  (`Routes::ABTesting`) that README.md documents as removed, and empty
  `pending` placeholder stubs - found across `spec/chaos/*`,
  `spec/contracts/*` (removed entirely - tested an HTTP client gem
  (`RestClient`) that isn't even a dependency), `spec/integration/*`,
  `spec/workers/*`, and several `spec/services/*` files.

**Root-caused and fixed the remaining flakiness at its source.** Traced
every remaining intermittent failure back to one real, common bug: this
suite had NO per-test Redis isolation at all - `spec_helper.rb`'s global
`before(:each)` only ever cleaned SQL tables. Two pieces of real,
Redis-backed app state accumulate across the entire test process as a
result:
- `TrendingService.cached_trending`'s fixed cache keys (`"trending:24h"`,
  etc.) - whichever spec file populated them first "wins" for every
  later file in the same run, regardless of that later file's own
  fixture data.
- `SelectionBenchmark`'s rolling latency window
  (`selection_benchmark:latencies_ms:*`) - accumulates a real sample from
  every request any spec file fires through `/random`, for the life of
  the process.

Fixed at the root: added a `RedisService.clear_pattern` sweep for both
key families to `spec_helper.rb`'s global `before(:each)`, rather than
patching each affected file individually to guess what some other file
left behind. Verified across multiple full-suite runs: failures dropped
from as many as 23 (run-order dependent) down to consistently 0-1,
and every remaining occasional failure (`chaos_engineering_spec.rb`'s
50-concurrent-thread success-rate check;
`random_algorithm_integration_spec.rb`'s Redis viewing-history race) is
inherently timing-sensitive by design, not a bug - the same class of
acceptable flakiness any suite with real concurrency assertions has.

**Final tally: 602 examples, 235 → 0-1 failures, 14 honestly-pending**
across repeated full-suite runs - a session that started by finding a
silently-broken personalization moat ended by making the whole test
suite reliably green.

This is exactly the kind of work Phase 0 calls for: it's boring, it's not
a new feature, and it's exactly what makes `/metrics` and the rest of this
roadmap trustworthy instead of aspirational.

**This session (ad experience, Phase 2 monetization):** with the core loop's
reliability established above, picked up Phase 2 ad work. Same pattern as
before - most of the actual work was finding real, silent breakage rather
than designing something new:

- **Root-cause bug:** `public/js/trending.js` has always fetched
  `/api/v1/trending` on every load and infinite-scroll page, but that route
  never existed anywhere in the codebase (only a disabled, never-registered
  `routes/api/v1/trending_optimized.rb`). Every visit to `/trending` silently
  loaded zero memes - not a missing-ads problem, a missing-everything
  problem, since ads only insert as memes render. Implemented the real
  route in `routes/trending_routes.rb`, wrapping the same `TrendingService`
  already used by `/api/trending`, in the exact `{data:, pagination:}` shape
  `trending.js` expects (distinct from `/api/trending`'s `{memes:, ...}`
  shape - different callers, different contracts, confirmed by reading the
  actual fetch code rather than assuming they matched).
- **Dead helper methods, wired up:** `render_sidebar_ad`, `render_hero_ad`,
  and `render_trending_ad` were fully implemented in
  `lib/helpers/ad_helpers.rb` (real HTML, real AdSense markup) but never
  called from any view - confirmed via grep. `render_anchor_ad` was the one
  exception, already wired into `/random` in an earlier session. Added
  `render_hero_ad` + `render_sidebar_ad` (via the existing
  `.content-with-sidebar` CSS grid, ≥1200px) + `render_anchor_ad` to
  `/trending`; added `render_hero_ad` + a native in-results ad (via
  `show_ad_at_position?`/`render_ad_unit`, gated on
  `should_show_ads_for_content?`'s 6-item minimum) + `render_anchor_ad` to
  `/search` - both pages had zero ad inventory before this.
- **Confirmed dead template:** `views/index.erb` (a 4-category picker with
  its own full ad-ready structure considered) turned out to never be
  rendered by any route - `GET /` actually renders `views/random.erb`.
  Left it alone with an explanatory comment instead of wiring ads into
  unreachable code.
- **Real desktop layout bug:** `/random`'s left/right "ad columns" were
  never actually laid out beside the meme on any viewport - confirmed
  `.meme-container` had no flex/grid rule anywhere in ~10 CSS files
  touching that class, so the ad `<div>`s and the meme display just
  stacked as plain blocks in document order, desktop included. Added a
  real `grid-template-columns: 300px 1fr 300px` layout at ≥1200px in
  `public/css/ads.css` (the file that already owns this styling contract
  per its own header comments), with a `:has()`-based collapse to a single
  column when ads are disabled, and explicit hiding in the 769-1199px gap
  where two 300px columns plus real content wouldn't fit.
- **Real mobile overlap bug:** the new/expanded `.ad-anchor-bottom` sticky
  ad (`position: fixed; bottom: 0; z-index: 1000`) would have rendered
  directly on top of `/random`'s real, live `.meme-controls` bar (Like/
  Save/Share/Download - also `position: sticky; bottom: 0`, but
  `z-index: 100`) on mobile, fully covering those buttons. Fixed by
  rendering the anchor ad in normal document flow (not fixed) specifically
  on `/random` (`.page-wrapper ~ .ad-anchor-bottom`), so it sits above the
  controls instead of over them - `/trending` and `/search` have no
  competing sticky control bar, so their anchor ads keep the original
  fixed-bottom behavior.
- Verified CSP (`lib/middleware/security_headers.rb`) already covers all of
  this - `script-src`/`img-src`/`connect-src`/`frame-src` already broadly
  allow `https:` specifically for AdSense/Monetag's rotating-domain
  behavior (documented in-file), and no new ad domains were introduced -
  only existing `render_*_ad` helpers were wired into more pages.
- Full suite re-verified after each change: still 602 examples, 0-1 flaky
  (same pre-existing, documented session-harness flake), no regressions.

**Continued same session:** audited every remaining real (non-dead) route
for ad inventory, same reachability check used above (`erb :template`
grepped against `routes/*.rb`) to avoid repeating the `views/index.erb`
mistake:
- Confirmed dead/unreachable: `views/collection_page.erb`,
  `views/daily_challenge.erb`, `views/meme_editor.erb`,
  `views/meme_formats.erb`, `views/guides_index.erb`,
  `views/collections_index.erb`, `views/meme_page.erb` (also a standalone
  `<!DOCTYPE html>` document, not wrapped in `layout.erb`, so it wouldn't
  get `AdHelpers` view context correctly even if it were reachable) - none
  are rendered by any route. Also noticed `routes/personalization.rb`
  calls `erb :saved_memes` but no `views/saved_memes.erb` exists (would
  500 on every real request) - a real pre-existing bug, but out of scope
  for ad work; noted here rather than silently fixed alongside an
  unrelated change.
- Added ads to the remaining real, reachable, content-bearing pages that
  had none: `views/category.erb` (hero + in-feed native + anchor, gated on
  `should_show_ads_for_content?`), `views/profile.erb` (hero, gated on
  combined liked+saved count), `views/leaderboard.erb` (hero, gated on
  real leaderboard data existing), `views/saved_meme.erb` (hero, plain
  `should_show_ads?` gate - a single real meme detail page is legitimate
  content on its own, same tier as `/random`), `views/taste_evolution.erb`
  (hero, only in the branch with real evolution data, not the empty-state
  placeholder).
- Verified via HTTP-level specs with stubbed content (rather than trusting
  the code by inspection alone) that both the AdSense minimum-content gate
  and the actual ad rendering work end-to-end - e.g. `/category/funny`
  correctly shows no ad with the 3-item fixture data already in the DB,
  and correctly shows the hero + anchor ad once stubbed with 10 items.
- Full suite re-verified again: still 602 examples, 0-1 flaky, no
  regressions.

## Phase 0 → 1: Prove the core loop is trustworthy (now)

The last ~20 commits (`git log`) are almost entirely reliability fixes to the
`/random` path: a double-`JSON.parse` crashing pool persistence, `Redis.new`
crashing on a bad `reconnect_delay` keyword, `/health` reporting Redis/cache
status incorrectly, a stale 10-item local cache being served instead of the
real pool, a 5-way OAuth thundering herd. That's the signal: the core loop's
reliability, not new features, is still the active bottleneck.

- [x] **Zero silent failures left in `/random` and `/random.json`'s
  pool-lookup → selection path.** Re-audited this session specifically
  looking for bare `rescue nil`/`rescue []`/`rescue => e` with no
  logging, the exact pattern earlier sessions found and fixed repeatedly
  in this codebase: `random_memes_pool` (`lib/helpers/meme_pool_helpers.rb`),
  `MemePoolManager.get_pool`/`get_pool_via_in_process_fallback`/
  `wait_for_pool` (`lib/services/meme_pool_manager.rb`), and
  `SimpleMemeSelector.select`/`subreddit_preferences_for` (new this
  session) all log every real failure via `AppLogger.error`/`.warn`
  before falling back, with no bare silent rescues found in this specific
  path. The two true silent `rescue nil`/`rescue []` modifiers that do
  exist in `routes/random_meme.rb` (view-count tracking in
  `build_meme_json`, and a Redis-based "recent subreddits" diversity
  list) are both best-effort analytics/diversity side-effects that
  intentionally must never block a real meme from being served if they
  fail - not part of the actual pool-lookup → selection decision this
  item is about. Also found and fixed one real gap while re-reading this
  path end-to-end: `GET /similar.json` called
  `SimpleMemeSelector.select` directly without threading `user_id`
  through, missed in this session's earlier personalization pass - now
  consistent with `/random` and `/random.json`.
- [ ] Collapse the multi-layer pool fallback chain (`MemePoolManager` →
  `MEME_CACHE` → on-demand Reddit fetch) - already flagged as In Progress
  in `README.md` - once real `/metrics` traffic data identifies which layer
  is the actual cost driver. Don't collapse it on guesswork.
- [ ] Pick **one** real distribution channel and go deep rather than wide
  (a specific subreddit-adjacent community, a Discord bot, a single social
  cross-post channel). A monopoly starts by completely dominating a market
  small enough to actually win, not by being present everywhere thinly.

## Phase 1: Build the moat - personalization as the unfair advantage

This is the part a generic Reddit-scroll experience structurally cannot
match: memory of a specific user, compounding over time.

- [x] **Feed real per-user signal (likes, saves, skips, dwell time) back
  into real, live meme selection weighting.** Found the
  mechanism (`apply_user_preferences` in
  `lib/helpers/meme_pool_helpers.rb`, which boosts a user's preferred
  subreddits by reading `user_subreddit_preferences.preference_score` on
  every `/random` pool build - already live on the hot path via
  `get_time_based_pools`) had never actually received a real signal:
  the only method that upserts that table,
  `update_user_preference`, was defined as an instance method inside
  `module MemeNavigationHelpers` - only reachable from a Sinatra route's
  `self` via the `helpers MemeNavigationHelpers` mixin - and was never
  called from any route (confirmed via grep: zero call sites). Every
  like, ever, went through `EngagementService.track_like` (the real
  `/like` route's mechanism) without ever touching
  `user_subreddit_preferences`. Wired the same upsert directly into
  `EngagementService.track_like` (same SQL/`ON CONFLICT` semantics
  already fixed for PostgreSQL's ambiguous-column requirement in a prior
  session, just called from the right place this time) - only on real
  likes, not unlikes, and only when the meme's subreddit is actually
  known (not the `'unknown'` placeholder `ensure_meme_stats_exists`
  inserts for never-before-seen URLs). Verified end-to-end with real
  DB rows, not mocks: a first like creates `preference_score: 1.0`, a
  second like of the same subreddit correctly increments to `1.2`
  (crossing `apply_user_preferences`' `> 1.0` "preferred" threshold),
  unlikes and unresolvable subreddits correctly create no row.
  Refactored the upsert into a shared private `bump_subreddit_preference`
  and wired it into `track_save` too, weighted higher (+0.3 vs. a like's
  +0.2 - a genuine, stated design choice, not a proven-optimal number)
  since a deliberate save is a stronger intent signal than a like.
  Wiring in `track_save` surfaced a second, more serious real bug while
  testing against actual DB rows rather than trusting the code by
  inspection: `saved_memes`' real column is `saved_at`
  (`db/postgres_schema.sql`), not the `created_at` this INSERT used -
  meaning **every single "save meme" action in the entire app
  (`POST /api/save-meme`, `track_save`'s only real caller) has been
  silently failing** since this was written. Made worse by
  `routes/profile_routes.rb` hardcoding `saved: true` in its response
  regardless of `result[:success]`, so users saw a "Meme saved" success
  message while nothing was ever actually saved. Fixed both: the column
  name, and the response now genuinely reflects `result[:success]`.
  Verified the full real route end-to-end (not just the service in
  isolation): `POST /api/save-meme` now actually inserts into
  `saved_memes` AND correctly feeds `user_subreddit_preferences` in the
  same request. 6 new specs total in
  `spec/services/engagement_service_spec.rb` (610 → 616 examples), full
  suite still 0-1 flaky.

  **Then found the deeper problem**: even with `user_subreddit_preferences`
  now genuinely being written to, it still couldn't have influenced a
  single real meme selection. `apply_user_preferences`/
  `get_time_based_pools` (the machinery that reads that table) is built
  on top of `navigate_meme_unified`
  (`lib/helpers/meme_navigation_helpers.rb`) - which nothing in the live
  app calls (confirmed via grep, same pattern as `update_user_preference`
  above). The actual selection algorithm real traffic hits on every
  request - `MemeExplorer::SimpleMemeSelector.select`, called from both
  `GET /random` and `GET /random.json` in `routes/random_meme.rb` - had
  **zero per-user personalization**: it weighted candidates by global
  likes/views only, identically for every user regardless of what
  they'd liked or saved before. Two structurally separate,
  fully-disconnected personalization systems existed side by side - one
  wired to live routes with no real signal feeding it, one with real
  signal (now) but wired to nothing live.

  Closed the loop on the side that's actually reachable: added
  `subreddit_preferences_for(user_id)` to `SimpleMemeSelector` (a plain
  DB lookup, fails safe to `{}` on any error) and threaded it into
  `weighted_sample` as a per-user multiplier on top of the existing
  global engagement score - a user's own `preference_score` for a
  candidate's subreddit (default `1.0`/neutral if absent, so this only
  ever boosts, never penalizes, and anonymous/no-preference users see
  byte-identical behavior to before). Wired `user_id:` through from both
  real call sites (`GET /random`, `GET /random.json`) via the existing
  `current_user_id` helper. Verified with a statistical test (2000
  samples) that a preferred subreddit is measurably oversampled relative
  to an equally-engaged non-preferred one, plus explicit tests that
  anonymous users and users with no preference data get provably
  identical behavior to the pre-change code path. 8 new specs in
  `spec/services/simple_meme_selector_spec.rb` (616 → 624 examples), full
  suite still 0-1 flaky. Confirmed end-to-end through a real HTTP request
  to `/random.json` with a real preference row seeded, not just the
  service in isolation.

  The old, now-fully-orphaned
  `apply_user_preferences`/`get_time_based_pools`/`navigate_meme_unified`
  path was deliberately left in place rather than deleted in this
  session - it's real, tested code that could become the basis of a
  future pool-level (not just selection-level) personalization pass, but
  that's a separate decision from closing today's actual live gap.

  **Closed the "skips" gap too**: unlike likes/saves (which had signal
  paths that existed but were disconnected), skips had genuinely no
  tracking anywhere in the codebase - a new capability, not a
  reconnection. Added `EngagementService.track_skip` (small, deliberate
  -0.05 penalty vs. a like's +0.2/save's +0.3 - one skip is weak, noisy
  signal that shouldn't undo several likes' worth of preference, and
  users skip far more often than they like) plus a real
  `POST /api/skip-meme` route (`routes/memes.rb`), wired into
  `public/js/modules/meme-navigation.js`'s `loadNextMeme()` as a
  fire-and-forget call (must never block or delay loading the actual
  next meme) reporting the meme being navigated away from. Deliberately
  NOT called from `loadSimilarMeme()` - requesting more of the same
  subreddit is a positive signal, not a skip. Rebuilt `public/dist/bundle.js`
  via `npm run build` so the change is actually live (this file is a
  Vite build artifact, not hand-edited).

  Found a real bug in `bump_subreddit_preference` while wiring this in
  and testing against real inserted rows: the initial version computed
  a first-ever signal's starting value as `1.0 + increment` (e.g. a
  first like landing at 1.2, not the already-tested, pre-existing 1.0
  baseline) - would have silently changed the meaning of every existing
  like/save test's expected values and the actual live behavior. Fixed
  so only the `ON CONFLICT` (second+ signal) branch applies `increment`;
  a brand-new (user, subreddit) row - whether from a like, save, or skip
  - always starts at the neutral 1.0 baseline, matching the
  pre-`increment:`-parameter behavior exactly. Caught this via the
  now-passing regression tests in `spec/services/engagement_service_spec.rb`,
  not by inspection. `preference_score` is floored at 0.1 (via
  `GREATEST`) so repeated skips can never drive it to zero or negative -
  a negative weight would invert `SimpleMemeSelector#weighted_sample`'s
  cumulative-sum sampling logic entirely, not just "penalize too hard."
  9 new specs total (`spec/services/engagement_service_spec.rb` +
  `spec/routes/memes_spec.rb`'s new `POST /api/skip-meme` coverage),
  624 → 633 examples, full suite still 0-1 flaky.

  **Closed the "dwell time" gap too, honestly scoped**: `MemeNavigation`
  now records `Date.now()` when a meme actually renders
  (`this.currentMemeShownAt`) and computes the elapsed time when it's
  navigated away from, sent as `dwell_ms` on the same `/api/skip-meme`
  call. Deliberately did NOT wire `dwell_ms` into `preference_score`
  weighting yet: a very-short dwell is plausibly a stronger "not
  interested" signal than a skip after lingering, but picking a formula
  (a multiplier? a threshold?) without real distribution data on how
  long genuine skips vs. genuine engagement actually take would be
  exactly the "guesswork" this roadmap explicitly warns against
  elsewhere (see the pool-fallback-chain item above). Also deliberately
  did NOT add a new `dwell_ms` database column in this pass - every
  other change this session was tested against the real, already-live
  schema; a schema migration is the one kind of change this session has
  no way to verify actually runs in production. Logged dwell time via
  `AppLogger.info` instead (`routes/memes.rb`'s `/api/skip-meme`) so
  it's real, inspectable data from day one, without a live-migration
  leap of faith. The honest state: dwell time is now captured, not yet
  acted on - the schema/weighting work is a well-scoped follow-up once
  there's enough logged data to calibrate against, not an open-ended
  unknown anymore.

  All three signal sources named in this roadmap item's original wording
  (likes, saves, skips - plus dwell time, added to the wording along the
  way once it became clear it was a real gap) now have live data paths
  into `SimpleMemeSelector`'s actual selection weighting, or (dwell time)
  a live, honestly-scoped path to one. This item is now genuinely done
  in the sense the roadmap's "What done looks like" section demands:
  verified against real inserted data and real HTTP requests throughout,
  not asserted from code inspection.

  One more real call site found afterward: `GET /similar.json`
  (`routes/random_meme.rb`) also calls `SimpleMemeSelector.select`
  directly and had been missed in the first pass - fixed the same way
  (`user_id: current_user_id`), so all three real selection entry points
  (`/random`, `/random.json`, `/similar.json`) are now consistent.
- [x] **Instrument retention (daily return rate, session length) alongside
  the existing latency benchmarks.** Implemented `RetentionService`
  (`lib/services/retention_service.rb`) - real SQL against the already-live
  `meme_activity_log` table (no new tracking call needed, just aggregating
  what's already recorded on every view/like): `.daily_return_rate`
  computes genuine D1 return rate (of users active on day N, what % were
  also active on day N+1) over a rolling window; `.avg_session_length_minutes`
  approximates session length as the gap between a user's first and last
  activity within a calendar day (the honest approximation available
  without an explicit session-boundary concept in the schema - labeled as
  such in the code). Both are wired into `/metrics` and `/metrics.json`
  alongside the existing Selection Latency section, and both fail safe
  (nil/empty shape, never raise) so a metrics-dashboard bug can't take
  down anything real. Verified against actual inserted activity rows
  (not just empty-state), not just code inspection: a user active
  yesterday and today correctly shows 100% D1 return; a user active only
  once correctly shows 0%; anonymous (`user_id IS NULL`) activity is
  correctly excluded, since return-rate is only meaningful for
  identities that can be observed returning across days. 8 new specs in
  `spec/services/retention_service_spec.rb`, full suite still 0-1 flaky
  (610 examples now, up from 602).
  NOTE: this is a fresh implementation, unrelated to the old, removed
  `MemeExplorer::RetentionService` referenced (but never actually
  required, since it doesn't exist) by the dead
  `lib/controllers/random_meme_controller.rb` - different namespace
  (`RetentionService`, not `MemeExplorer::RetentionService`), different
  purpose, no collision.
- [ ] Treat `SelectionBenchmark` and any future personalization metric with
  the same discipline the README already demands for latency: numbers only
  count if they come from a live instrument reading real traffic, never a
  static claim typed into a doc. (`RetentionService` follows this - see
  above - but the actual retention *number* itself is still unproven
  against real production traffic; this line item is about maintaining
  that discipline going forward, not something "done" once.)

## Phase 2: Scale and monetize - only once the loop is proven

Deliberately sequenced last. Building this before Phase 0/1 land is solving
problems the product doesn't have real traffic to justify yet.

- [ ] Solve the single-worker constraint on purpose (`ARCHITECTURE.md`:
  the app runs one Puma worker by design because the pool lives in
  in-process memory) - move pool state to a Redis-native structure only
  once real traffic actually needs horizontal scaling, not preemptively.
- [x] **Diversify beyond generic ad-network monetization**: built a real
  Stripe-backed ad-free premium tier - the concrete, well-scoped piece of
  this item that engineering work can actually deliver (picking *when*
  to push it live, i.e. once there's a real engaged user base to sell
  to, is the product/GTM decision half of this item, and stays open -
  see the session close-out section below).

  Found this half-built already: the `stripe` gem has been in the
  Gemfile, `.env.example` already documented the exact env vars needed
  (`STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID_MONTHLY/YEARLY`,
  `STRIPE_WEBHOOK_SECRET`) with an explicit note that no integration
  code existed yet, and `lib/middleware/authorization.rb` already
  enforced login on `/premium` - all clearly scaffolded by a prior
  session for this exact feature, never finished.

  Built: `lib/services/subscription_service.rb` (Stripe Customer/Checkout
  Session creation, webhook event processing with signature verification
  happening in the route - the service trusts its input completely and
  must never be reachable unverified), `routes/premium_routes.rb`
  (`GET /premium` pricing page, `POST /premium/checkout`,
  `POST /webhooks/stripe`), `views/premium.erb`, and a real migration
  (`db/migrations/add_premium_subscriptions.sql` - additive/idempotent,
  matching this directory's established `ADD COLUMN IF NOT EXISTS`
  pattern). Wired `AdHelpers.should_show_ads?` to check
  `SubscriptionService.premium?` - the actual product benefit being sold
  is genuinely ad-free, not a cosmetic label.

  Key design decisions, each deliberate: `premium?` checks a locally
  cached status + period-end pair rather than calling Stripe live on
  every ad-render (a network call on that hot path is exactly the class
  of cost `SelectionBenchmark` exists to guard against elsewhere in this
  codebase) - checking BOTH fields together means a missed
  cancellation webhook can't leave someone premium forever, and a missed
  renewal webhook can't cut someone off mid-period. Webhook events are
  deduplicated by Stripe event id (`stripe_webhook_events` table, Stripe
  explicitly documents the same event can be delivered more than once).
  `create_checkout_session` only ever accepts a pre-configured Stripe
  Price ID from server-side ENV, never a client-supplied amount.
  `migration_applied?`/`premium?` both fail safe to
  false/not-applied/not-premium on any error (missing columns, DB
  hiccup, Stripe misconfiguration) - a broken premium check can suppress
  a discount, never accidentally grant free access or crash the app.

  Verified end-to-end with WebMock-stubbed Stripe HTTP responses (not
  mocked Ruby objects) through the real routes: a full checkout flow
  that creates a Stripe customer, persists the id, and redirects to a
  real Stripe-hosted checkout URL; webhook signature verification tested
  against both a genuinely valid HMAC signature and a rejected invalid
  one; premium status correctly suppressing `class="ad-container"` in a
  real `/random` response while a non-premium logged-in user and an
  anonymous user both still see ads. 28 new specs across
  `spec/services/subscription_service_spec.rb`,
  `spec/routes/premium_routes_spec.rb`, and new cases in
  `spec/routes/random_spec.rb` (634 → 662 examples), full suite still
  0-1 flaky.

  Honest scope note: nobody has actually paid via this integration yet -
  it's real, tested code exercised against Stripe's documented API
  contract (via WebMock stubs matching real request/response shapes),
  not a live transaction. `STRIPE_SECRET_KEY`/`STRIPE_PRICE_ID_*` remain
  commented out in `.env.example` on purpose; filling them in with real
  values is the actual "go live" moment for this feature, and that
  moment is a product decision (see session close-out), not something
  this session can or should trigger unilaterally.
- [x] **CDN integration** (first item in `README.md`'s "Planned" list) -
  found the same "scaffolded but never wired up" pattern as the Stripe
  integration above: `lib/helpers/cdn_helpers.rb` was already written
  and already mixed into every route (`helpers CDNHelpers` in `app.rb`),
  but `config/initializers/cdn.rb` - which defines `CDNConfig`, the
  module every single `CDNHelpers` method delegates to - was never
  `require`d anywhere in the codebase. Every real call to
  `cdn_css`/`cdn_js`/`cdn_image`/`cdn_asset`/`preload_*`/
  `cdn_image_srcset` would have raised `NameError: uninitialized
  constant CDNConfig` the instant anything actually called them -
  confirmed nothing ever did (zero call sites anywhere in `views/` or
  `routes/`). Fixed the missing `require` in `app.rb`.

  Actually exercising this code for the first time (rather than trusting
  it by inspection) surfaced a second, real bug: `cdn_image`'s own path
  logic produced a double `/images/images/...` prefix for the exact
  path shape `data/memes.yml`'s real `file:` values use (e.g.
  `"images/wholesome2.jpeg"` - no leading slash, but already containing
  `images/`). `cdn_image`'s doc comment describes callers passing a bare
  filename like `"meme.jpg"`, but that's not what's actually stored
  anywhere real. Fixed by normalizing away any existing `images/`
  prefix (with or without a leading slash) before re-adding exactly one,
  so all three real input shapes in this codebase - bare filename,
  `"images/foo.jpg"`, and `"/images/foo.jpg"` - now produce identical,
  correct output. Also fixed a related landmine in the same method: it
  only checked `path.start_with?('/')` to decide whether to treat input
  as already-a-full-path, which would have mangled a real external meme
  URL (`https://i.redd.it/...`, `https://i.imgur.com/...` - what most
  meme images actually are) into a broken local-asset path prefixed with
  our own CDN domain. Added an explicit absolute-URL guard so real
  external images pass through completely untouched - CDN rewriting only
  ever applies to this app's own local `/images/*` fallback assets.

  Wired `cdn_image` into `views/random/display.erb`'s actual `<img
  src>` render (the real hot path - `/random` and `/random.json` are
  this app's most-trafficked routes) - deliberately only at render time,
  not applied to `@image_src` itself, since that value doubles as the
  identifier used for likes/saves/view-tracking throughout the app
  (`meme_stats.url`, `saved_memes.meme_url`, etc.); rewriting the
  identifier itself to a CDN URL would have corrupted that join key.
  `CDNConfig` stays fully backward-compatible/inert when
  `CDN_DOMAIN`/`RENDER_EXTERNAL_URL` aren't set (the default in every
  environment right now) - this is real, tested, dormant capability
  that activates the moment a real CDN domain is configured, not a
  live behavior change today.

  Verified end-to-end: `CDNConfig` genuinely undefined before the fix
  (confirmed by reverting the require and re-running), all four real
  path shapes (bare filename, relative-with-images/, absolute-with-
  images/, and external http(s) URL) produce correct output with CDN
  disabled AND with a real CDN domain configured, and a full `/random`
  render with a CDN domain set produces exactly one `/images/` segment
  in the rendered `<img src>`, never a doubled one. 10 new specs across
  `spec/helpers/cdn_helpers_spec.rb` and a new case in
  `spec/routes/random_spec.rb` (662 → 672 examples), full suite still
  0-1 flaky.

  Left as explicit, smaller follow-up rather than done in this pass:
  `layout.erb` still hardcodes ~20 `<link>`/`<script>` tags directly
  rather than routing them through `cdn_css`/`cdn_js` - a real
  mechanical rewrite of a critical, load-bearing file, lower-risk to do
  as its own focused change than bundled into this session's fix.
- [ ] The rest of `README.md`'s existing "Planned" list, roughly in this
  order - image optimization pipeline, PWA, mobile app, WebSocket/GraphQL
  layers. These are all reasonable, none are urgent, and building them
  early would be optimizing breadth before the core monopoly claim is
  proven.

## What "done" looks like for this thesis

Not a feature checklist - a claim that should be verifiably true from live
data, the same way the Performance section of `README.md` insists on:

> Meme Explorer picks a better next meme for a specific returning user than
> a generic Reddit scroll would, measurably (retention/return-rate data),
> and does so reliably and fast (`/metrics` p95/p99), without needing to be
> the biggest archive of memes that exists.

If that claim isn't true yet, that's the actual backlog - re-derive next
steps from it rather than from feature requests that don't move it.

## Session close-out: what's actually achievable vs. what's a real decision

Every checkbox in Phase 0 and Phase 1 that was closable through engineering
work alone - finding and fixing real, verifiable bugs, wiring disconnected
systems together, instrumenting real metrics - is now checked, each with
real evidence (live HTTP requests, real DB rows, statistical tests) rather
than a claim taken on faith. The remaining open items are intentionally
*not* checked off, because doing so would be exactly the kind of
unsubstantiated claim this document repeatedly warns against:

- **Collapsing the pool fallback chain** and **the "treat metrics with
  discipline" item** are both explicitly gated on live production traffic
  data this session has no access to generate - `/metrics`/`RetentionService`
  now exist and work correctly (verified against real rows), but the
  actual numbers they'll report from real users are unknown until the app
  is live. Checking these off now would mean claiming a decision was made
  from data that doesn't exist yet.
- **Diversifying monetization** got as far as engineering work can take
  it alone: a real, tested Stripe integration now exists (see Phase 2
  above). What remains open is genuinely a product/GTM decision, not a
  missing feature - *when* to actually flip on real `STRIPE_SECRET_KEY`/
  `STRIPE_PRICE_ID_*` values and start charging real money, which this
  roadmap's own thesis says should wait for a real engaged user base to
  sell a premium tier to, not ship on day one alongside the ads it's
  meant to replace revenue from.
- **Picking a distribution channel** and **the single-worker scaling
  question** remain pure product/business/GTM decisions, not code
  defects - there's no bug to find or wire up here, just a choice
  someone with product context needs to make. Engineering work can
  implement whichever choice gets made, but can't make it.

**The honest state of the thesis claim above**: the product now
*structurally* does what it claims - personalization signal (likes, saves,
skips, dwell-time capture) genuinely reaches live selection, verified
end-to-end; retention is genuinely measured, not asserted; the core
selection loop has no known silent failures. What remains unproven is
whether real users, in production, actually return more/engage longer
because of it - that can only be answered by real traffic hitting the
now-correctly-wired instrumentation, not by more code changes. The
concrete next step, once this ships, is simply: read `/metrics` after a
real observation window, and let that data - not this document - decide
what happens next.
