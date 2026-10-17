import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const share_path = `/meme/${'a'.repeat(64)}`;
const source = await readFile(new URL('../../public/js/modules/meme-navigation.js', import.meta.url), 'utf8');
const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

function setup() {
  let stored;
  const nav = Object.create(MemeNavigation.prototype);
  nav.renderRecentMemes = () => {};
  const storage = {
    getItem: () => stored,
    setItem: (_key, value) => { stored = value; },
    removeItem: () => { stored = null; }
  };
  return { nav, storage, data: () => JSON.parse(stored) };
}

test('recent history survives refresh without persisting account or delivery state', () => {
  const previous = globalThis.window;
  const app = setup();
  globalThis.window = { sessionStorage: app.storage };
  try {
    app.nav.rememberRecentMeme({ url: '/image.jpg', share_path, title: 'Example', impression_id: 'secret', liked: true, saved: true, video_url: 'https://example.com/private.mp4', content_id: 'unused' });
    assert.deepEqual(app.data().items, [{ url: '/image.jpg', share_path, title: 'Example' }]);
    app.nav.recentMemes = [];
    app.nav.restoreRecentMemes();
    assert.equal(app.nav.recentMemes[0].url, '/image.jpg');
    app.nav.recentMemes = [];
    app.nav.persistRecentMemes();
    app.nav.restoreRecentMemes();
    assert.deepEqual(app.nav.recentMemes, []);
  } finally { globalThis.window = previous; }
});

test('stored history is bounded, deduplicated, and excludes incomplete galleries', () => {
  const previous = globalThis.window;
  const app = setup();
  globalThis.window = { sessionStorage: app.storage };
  try {
    for (let index = 0; index < 25; index++) app.nav.rememberRecentMeme({ url: `/image-${index}.jpg`, share_path });
    assert.equal(app.data().items.length, 20);
    app.nav.rememberRecentMeme({ url: '/gallery.jpg', is_gallery: true, gallery_images: ['/a.jpg'] });
    assert.ok(!app.data().items.some(item => item.url === '/gallery.jpg'));
    app.storage.setItem('', JSON.stringify({ version: 1, items: [{ url: '/a.jpg', share_path }, { url: '/a.jpg', share_path }, { url: 'javascript:alert(1)' }] }));
    app.nav.restoreRecentMemes();
    assert.deepEqual(app.nav.recentMemes, [{ url: '/a.jpg', share_path, restoredFromStorage: true }]);
  } finally { globalThis.window = previous; }
});

test('unavailable, oversized and malformed storage cannot break history', () => {
  const previous = globalThis.window;
  const app = setup();
  try {
    globalThis.window = { get sessionStorage() { throw new Error('blocked'); } };
    assert.doesNotThrow(() => app.nav.rememberRecentMeme({ url: '/a.jpg', share_path }));
    assert.doesNotThrow(() => app.nav.restoreRecentMemes());
    globalThis.window = { sessionStorage: app.storage };
    for (const invalid of ['{', 'null', 'x'.repeat(131073), JSON.stringify({ version: 2, items: [] })]) {
      app.storage.setItem('', invalid);
      assert.doesNotThrow(() => app.nav.restoreRecentMemes());
      assert.equal(app.nav.recentMemes[0].url, '/a.jpg');
    }
  } finally { globalThis.window = previous; }
});

test('refresh-restored entries reload their exact server page, never stale account state', async () => {
  const previous = globalThis.window;
  const app = setup();
  let destination;
  globalThis.window = { sessionStorage: app.storage, location: { assign: path => { destination = path; } } };
  try {
    app.nav.rememberRecentMeme({ url: '/a.jpg', share_path, saved: true });
    app.nav.restoreRecentMemes();
    app.nav.renderMeme = () => assert.fail('Restored entries require server state');
    await app.nav.openRecentMeme(0);
    assert.equal(destination, share_path);
    assert.equal(app.nav.recentMemes[0].saved, undefined);
  } finally { globalThis.window = previous; }
});

test('history without an exact local permalink is never persisted', () => {
  const app = setup();
  for (const path of [undefined, '/random', '//evil.example', 'https://evil.example/meme/test']) {
    assert.equal(app.nav.recentSnapshot({ url: '/a.jpg', share_path: path }), null);
  }
});