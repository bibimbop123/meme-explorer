import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../public/js/cookie-consent.js', import.meta.url), 'utf8');

for (const pathname of [`/meme/${'a'.repeat(64)}`, '/meme/not-an-id']) {
test(`recipient page ${pathname} never initializes ad consent or advertising`, () => {
  let injections = 0;
  const context = {
    window: { location: { pathname } },
    document: {
      readyState: 'complete',
      querySelector: () => null,
      createElement: () => { injections++; return { setAttribute() {} }; },
      head: { appendChild() { injections++; } }
    },
    localStorage: { getItem() { assert.fail('recipient page must not initialize ad consent'); } }
  };
  vm.runInNewContext(`${source}\nCookieConsent.prototype.loadMonetag.call({});`, context);
  assert.equal(injections, 0);
});
}

test('normal desktop browsing retains accepted-consent ad loading', () => {
  const scripts = [];
  const context = {
    window: { location: { pathname: '/random' }, innerWidth: 1200 },
    navigator: { userAgent: 'Desktop' },
    console: { log() {} },
    localStorage: { getItem: () => 'accepted' },
    document: {
      readyState: 'complete', querySelector: () => null,
      createElement: () => ({ setAttribute() {} }),
      head: { appendChild: script => scripts.push(script) }
    }
  };
  vm.runInNewContext(source, context);
  assert.equal(scripts.length, 1);
  assert.equal(scripts[0].src, 'https://quge5.com/88/tag.min.js');
});