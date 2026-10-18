import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/share-system.js', import.meta.url), 'utf8');
const originalDocument = globalThis.document;
globalThis.document = { readyState: 'loading', addEventListener() {} };
const { exactShareData, twitterIntent, initializeShareButtons } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
globalThis.document = originalDocument;

test('Tweet reads current displayed identity at click time and encodes text exactly once', () => {
  const previous = { document: globalThis.document, window: globalThis.window };
  let path = `/meme/${'a'.repeat(64)}`;
  let title = `It's funny 😎 & 100% "exact"`;
  globalThis.window = { location: { href: 'https://memes.example/?private=query' } };
  globalThis.document = { querySelector: selector => selector === '#viewer-share-data' ? { dataset: { sharePath: path } } : { textContent: title } };
  const container = { querySelector: () => ({}), dataset: {} };
  try {
    let intent = new URL(twitterIntent(exactShareData(container)));
    assert.equal(intent.searchParams.get('text'), title);
    assert.equal(intent.searchParams.get('url'), `https://memes.example${path}`);
    assert.equal(intent.searchParams.has('hashtags'), false);
    path = `/meme/${'b'.repeat(64)}`; title = 'Another meme';
    intent = new URL(twitterIntent(exactShareData(container)));
    assert.equal(intent.searchParams.get('text'), title);
    assert.equal(intent.searchParams.get('url'), `https://memes.example${path}`);
    for (const invalid of ['', '/random', '//evil.example', '/meme/not-an-id']) {
      path = invalid;
      assert.equal(exactShareData(container), null);
    }
  } finally { Object.assign(globalThis, previous); }
});

test('real Tweet button listener uses latest meme without inline handlers or stale closure', async () => {
  const previous = { document: globalThis.document, window: globalThis.window };
  const buttons = [];
  let path = `/meme/${'a'.repeat(64)}`;
  let title = 'First';
  let opened;
  const container = { dataset: {}, querySelector: selector => selector === '#meme-display' ? {} : null, appendChild() {} };
  globalThis.document = {
    querySelectorAll: () => [container],
    querySelector: selector => selector === '#viewer-share-data' ? { dataset: { sharePath: path } } : { textContent: title },
    createElement: tag => {
      const element = { setAttribute() {}, appendChild() {}, addEventListener: (_, handler) => { element.click = handler; } };
      if (tag === 'button') buttons.push(element);
      return element;
    }
  };
  globalThis.window = { location: { href: 'https://memes.example/random' }, open: url => { opened = url; } };
  try {
    initializeShareButtons();
    path = `/meme/${'c'.repeat(64)}`; title = 'New 😎 meme';
    await buttons.find(button => button.textContent === 'Tweet link').click();
    assert.equal(new URL(opened).searchParams.get('url'), `https://memes.example${path}`);
    assert.equal(new URL(opened).searchParams.get('text'), title);
    assert.ok(!source.includes('onclick='));
  } finally { Object.assign(globalThis, previous); }
});