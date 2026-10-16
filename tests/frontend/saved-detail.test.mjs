import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../public/js/saved-detail.js', import.meta.url), 'utf8');
for (const outcome of ['success', 'rejected', 'http-error', 'network', 'invalid-json']) {
  test(`Saved removal handles ${outcome} truthfully`, async () => {
    let click;
    const button = { disabled: false, dataset: { returnPath: '/profile?saved_page=2#saved-card-7' }, addEventListener: (_, fn) => { click = fn; } };
    const status = {};
    const window = { location: { href: '/saved/7' } };
    vm.runInNewContext(source, {
      document: { getElementById: id => id === 'remove-saved-meme' ? button : status, querySelector: () => ({ value: '/a.jpg' }) },
      window, URLSearchParams,
      fetch: async () => {
        if (outcome === 'network') throw new Error('offline');
        return { ok: outcome !== 'http-error', json: async () => {
          if (outcome === 'invalid-json') throw new Error('invalid JSON');
          return { success: outcome !== 'rejected', unsaved: true };
        } };
      }
    });
    await click();
    assert.equal(button.disabled, false);
    if (outcome === 'success') {
      assert.equal(window.location.href, '/saved/7');
      assert.equal(button.textContent, 'Undo removal');
    }
    else {
      assert.equal(window.location.href, '/saved/7');
      assert.match(status.textContent, /Please try again/);
    }
  });
}

test('Saved removal blocks duplicate requests and stays on the detail page', async () => {
  let click;
  let finish;
  let calls = 0;
  const button = { disabled: false, dataset: { returnPath: '//evil.example' }, addEventListener: (_, fn) => { click = fn; } };
  const window = { location: { href: '/saved/7' } };
  vm.runInNewContext(source, {
    document: { getElementById: id => id === 'remove-saved-meme' ? button : {}, querySelector: () => ({ value: '/a.jpg' }) },
    window, URLSearchParams,
    fetch: () => { calls++; return new Promise(resolve => { finish = resolve; }); }
  });
  const pending = click();
  assert.equal(button.disabled, true);
  await click();
  assert.equal(calls, 1);
  finish({ ok: true, json: async () => ({ success: true, unsaved: true }) });
  await pending;
  assert.equal(button.disabled, false);
  assert.equal(window.location.href, '/saved/7');
});

test('Undo restores metadata and allows retry after a rejected restore', async () => {
  let click;
  const requests = [];
  let restoreAttempts = 0;
  const button = { dataset: { title: 'Favorite title', subreddit: 'cats' }, addEventListener: (_, fn) => { click = fn; } };
  const status = {};
  vm.runInNewContext(source, {
    document: { getElementById: id => id === 'remove-saved-meme' ? button : status, querySelector: () => ({ value: '/favorite.jpg' }) },
    URLSearchParams,
    fetch: async (path, options) => {
      requests.push({ path, body: options.body });
      const success = path.includes('unsave') || ++restoreAttempts > 1;
      return { ok: true, json: async () => ({ success, saved: success, unsaved: success }) };
    }
  });
  await click();
  await click();
  assert.match(status.textContent, /Could not restore/);
  assert.equal(button.textContent, 'Undo removal');
  await click();
  assert.equal(status.textContent, 'Favorite restored.');
  assert.equal(button.textContent, 'Remove');
  assert.equal(requests[1].path, '/api/save-meme');
  assert.equal(requests[1].body.get('title'), 'Favorite title');
  assert.equal(requests[1].body.get('subreddit'), 'cats');
  assert.equal(requests[1].body.get('url'), '/favorite.jpg');
});