import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('skip link targets a programmatically focusable main landmark without adding a Tab stop', async () => {
  const layout = await readFile(new URL('../../views/layout.erb', import.meta.url), 'utf8');
  assert.match(layout, /href="#main-content" class="skip-to-content"/);
  assert.match(layout, /<main id="main-content" role="main" tabindex="-1">/);
});

test('viewer layout overrides load after competing legacy responsive styles', async () => {
  const layout = await readFile(new URL('../../views/layout.erb', import.meta.url), 'utf8');
  assert.ok(layout.indexOf('viewer_stylesheet_path') > layout.indexOf('/css/mobile-optimizations-v2.css'));
  assert.ok(layout.indexOf('viewer_stylesheet_path') > layout.indexOf('/css/ads.css'));
});

test('mobile viewer CSS accounts for six controls and safe-area padding', async () => {
  const css = await readFile(new URL('../../public/css/viewer-controls.css', import.meta.url), 'utf8');
  assert.match(css, /repeat\(6, minmax\(0, 1fr\)\)/);
  assert.match(css, /safe-area-inset-bottom/);
  assert.match(css, /position: static !important/);
  assert.match(css, /min-height: 48px/);
  assert.match(css, /#download-btn/);
  assert.match(css, /grid-column: 1 \/ -1/);
});

test('viewer images use natural aspect and uncapped height while video remains bounded', async () => {
  const css = await readFile(new URL('../../public/css/viewer-controls.css', import.meta.url), 'utf8');
  const images = css.match(/\.simplified-mode #meme-display img \{([^}]+)\}/)[1];
  assert.match(images, /aspect-ratio: auto/);
  assert.match(images, /max-height: none !important/);
  assert.match(images, /height: auto !important/);
  const display = css.match(/\.simplified-mode #meme-display \{([^}]+)\}/)[1];
  assert.match(display, /overflow: visible/);
  assert.match(display, /max-height: none !important/);
  const video = css.match(/\.simplified-mode #meme-display video \{([^}]+)\}/)[1];
  assert.match(video, /max-height: 75vh !important/);
});

test('AJAX image wrappers grow with media rather than clipping absolute images in square slots', async () => {
  const css = await readFile(new URL('../../public/css/viewer-controls.css', import.meta.url), 'utf8');
  const wrapper = css.match(/\.simplified-mode #meme-display \.meme-image-container \{([^}]+)\}/)[1];
  assert.match(wrapper, /aspect-ratio: auto !important/);
  assert.match(wrapper, /height: auto !important/);
  assert.match(wrapper, /min-height: 0 !important/);
  assert.match(wrapper, /overflow: visible !important/);
  assert.match(css, /\.simplified-mode #meme-display \.meme-image-container img \{\s*position: static !important;/);
});