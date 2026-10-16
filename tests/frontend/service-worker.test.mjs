import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/service-worker.js', import.meta.url), 'utf8');
test('service worker bypasses dynamic viewer/session requests and third-party scripts', () => {
  const handlers = {};
  vm.runInNewContext(source, {
    self: { location: { origin: 'https://memes.example' }, addEventListener: (name, fn) => { handlers[name] = fn; } },
    URL, console
  });
  for (const path of ['/', '/random', '/random.json', '/similar.json', '/api/skip-meme', '/profile', '/saved/7', '/meme/abc', 'https://quge5.com/88/tag.min.js']) {
    handlers.fetch({
      request: { url: new URL(path, 'https://memes.example').href, method: 'GET', mode: 'navigate' },
      respondWith: () => assert.fail(`must not intercept ${path}`)
    });
  }
  handlers.fetch({ request: { url: 'https://memes.example/api/save-meme', method: 'POST' }, respondWith: () => assert.fail('must not intercept mutation') });
  assert.ok(!source.includes("  '/',"));
});