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

This is exactly the kind of work Phase 0 calls for: it's boring, it's not
a new feature, and it's exactly what makes `/metrics` and the rest of this
roadmap trustworthy instead of aspirational.

## Phase 0 → 1: Prove the core loop is trustworthy (now)

The last ~20 commits (`git log`) are almost entirely reliability fixes to the
`/random` path: a double-`JSON.parse` crashing pool persistence, `Redis.new`
crashing on a bad `reconnect_delay` keyword, `/health` reporting Redis/cache
status incorrectly, a stale 10-item local cache being served instead of the
real pool, a 5-way OAuth thundering herd. That's the signal: the core loop's
reliability, not new features, is still the active bottleneck.

- [ ] Zero silent failures left in `/random` and `/random.json`'s
  pool-lookup → selection path. Use `/metrics` (live p50/p95/p99 per stage,
  via `SelectionBenchmark`) as the source of truth, not assumptions.
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

- [ ] Feed real per-user signal (saves, skips, dwell time) back into
  `MemePoolManager`'s tier-distributed pool selection weighting - not just
  anti-repetition, but genuine preference learning. `/taste-evolution`
  already hints at this; make it actually drive selection, not just report
  on it after the fact.
- [ ] Instrument retention (daily return rate, session length) alongside
  the existing latency benchmarks. Latency proves the loop is fast;
  retention proves the loop is actually *better* for the user, which is
  the real test of a monopoly-shaped product versus a merely functional one.
- [ ] Treat `SelectionBenchmark` and any future personalization metric with
  the same discipline the README already demands for latency: numbers only
  count if they come from a live instrument reading real traffic, never a
  static claim typed into a doc.

## Phase 2: Scale and monetize - only once the loop is proven

Deliberately sequenced last. Building this before Phase 0/1 land is solving
problems the product doesn't have real traffic to justify yet.

- [ ] Solve the single-worker constraint on purpose (`ARCHITECTURE.md`:
  the app runs one Puma worker by design because the pool lives in
  in-process memory) - move pool state to a Redis-native structure only
  once real traffic actually needs horizontal scaling, not preemptively.
- [ ] Diversify beyond generic ad-network monetization (Monetag/PropellerAds
  - see recent CSP-fix commits) once there's an engaged, returning user base
  to justify pricing power: premium personalization, ad-free tier, etc.
  Commodity ad inventory is the wrong monetization model for a product
  whose thesis is personalization.
- [ ] Only after the above: the rest of `README.md`'s existing "Planned"
  list in roughly this order - CDN integration, image optimization
  pipeline, PWA, mobile app, WebSocket/GraphQL layers. These are all
  reasonable, none are urgent, and building them early would be optimizing
  breadth before the core monopoly claim is proven.

## What "done" looks like for this thesis

Not a feature checklist - a claim that should be verifiably true from live
data, the same way the Performance section of `README.md` insists on:

> Meme Explorer picks a better next meme for a specific returning user than
> a generic Reddit scroll would, measurably (retention/return-rate data),
> and does so reliably and fast (`/metrics` p95/p99), without needing to be
> the biggest archive of memes that exists.

If that claim isn't true yet, that's the actual backlog - re-derive next
steps from it rather than from feature requests that don't move it.
