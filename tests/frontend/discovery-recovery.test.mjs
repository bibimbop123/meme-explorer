import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../public/js/modules/meme-navigation.js', import.meta.url), 'utf8');
const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('enabled discovery controls do not issue speculative selections', () => {
  const navigation = { discoveryControlsActive: true, fetchMeme() { assert.fail('must not prefetch'); } };
  assert.equal(MemeNavigation.prototype.prefetchNext.call(navigation), undefined);
});

test('enabled discovery Next discards an old prefetch and requests current server state', async () => {
  const original = globalThis.document;
  globalThis.document = { getElementById: () => null };
  let fetched = 0;
  let rendered;
  const navigation = {
    discoveryControlsActive: true,
    prefetchedMeme: { url: '/blocked.jpg' },
    prefetchPromise: Promise.resolve(),
    currentMeme: { url: '/current.jpg' },
    navigationVersion: 1,
    beginNavigation: () => 1,
    showLoadingState() {}, hideLoadingState() {},
    fetchMeme: async () => { fetched++; return { url: '/allowed.jpg' }; },
    withConfirmedInteractions: meme => meme,
    renderMeme: async meme => { rendered = meme; },
    trackView() {}, prefetchNext() {},
    showError: message => assert.fail(message)
  };
  try {
    await MemeNavigation.prototype.loadNextMeme.call(navigation);
    assert.equal(fetched, 1);
    assert.equal(rendered.url, '/allowed.jpg');
    assert.equal(navigation.prefetchedMeme, null);
  } finally { globalThis.document = original; }
});

test('current-community form recovers from missing metadata and clears invalid targets', () => {
  const original = globalThis.document;
  const input = {};
  const button = {};
  const form = { hidden: true, querySelector: selector => selector === 'button' ? button : input };
  globalThis.document = { getElementById: () => form };
  try {
    MemeNavigation.prototype.updateDiscoveryCommunity({ subreddit: 'CaTs' });
    assert.equal(form.hidden, false);
    assert.equal(input.value, 'cats');
    assert.equal(button.textContent, 'Hide r/cats from Random');
    MemeNavigation.prototype.updateDiscoveryCommunity({ subreddit: '<script>' });
    assert.equal(form.hidden, true);
    assert.equal(input.value, '');
    MemeNavigation.prototype.updateDiscoveryCommunity({ subreddit: 'dogs' });
    assert.equal(form.hidden, false);
    assert.equal(input.value, 'dogs');
  } finally { globalThis.document = original; }
});

test('only explicit preference-exhaustion 409 is classified as discovery scarcity', async () => {
  const original = globalThis.fetch;
  try {
    globalThis.fetch = async () => ({ ok: false, status: 409, json: async () => ({ preferences_exhausted: true, error: '<untrusted>' }) });
    await assert.rejects(MemeNavigation.prototype.fetchMeme('/random.json'), error => error.preferencesExhausted === true && !error.message.includes('<untrusted>'));
    globalThis.fetch = async () => ({ ok: false, status: 409, json: async () => ({ error: 'Other conflict' }) });
    await assert.rejects(MemeNavigation.prototype.fetchMeme('/random.json'), error => error.message === 'HTTP 409' && !error.preferencesExhausted);
  } finally { globalThis.fetch = original; }
});

test('discovery scarcity adds actionable recovery without replacing displayed media', () => {
  const original = globalThis.document;
  const links = [];
  const notice = { textContent: '', appendChild: link => links.push(link) };
  globalThis.document = { getElementById: () => notice, createElement: () => ({}) };
  try {
    MemeNavigation.prototype.showPreferencesExhausted.call({ showError() {} });
    assert.match(notice.textContent, /current meme is still here/);
    assert.equal(links[0].href, '/random#discovery-controls');
    assert.match(links[0].textContent, /restore or reset/);
    assert.ok(!notice.textContent.includes('retry'));
  } finally { globalThis.document = original; }
});