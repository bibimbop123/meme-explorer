# Viewer asset deployment check

The web Blueprint builds the Vite bundle with:

```sh
bundle install && npm ci --include=dev && npm run build
```

Vite is a dev dependency, so production builds must explicitly include it.
Node 22 matches CI. Build must complete before Ruby starts: the viewer asset hash
is computed at boot from public/dist/bundle.js.

If the service was created manually or its settings override the Blueprint,
update its Render Build Command explicitly. Editing render.yaml alone does not
prove the running service adopted it. Look for successful Vite output in the
deployment build log and verify the deployed commit/branch.

After deployment:

1. Verify page source references /dist/bundle.js?v=<16-character hash>.
2. In DevTools Application, clear this site's service-worker/cache storage,
   then close/reopen tabs (or test a new private session).
3. Click Next once. Verify new content renders, and inspect /random.json and
   the media request if it fails. Prefetch can satisfy the first click without
   a new request, but subsequent prefetch should continue.
4. Current Next code does not call /api/skip-meme. If those calls continue,
   inspect the Network Initiator to identify the stale/different script.

The missing meme_catalog table is a separate migration problem; see
VIEWER_SCHEMA_RECOVERY.md. Do not run production migrations as a build step.
Asset rebuilding does not fix blocked external images or database outages.