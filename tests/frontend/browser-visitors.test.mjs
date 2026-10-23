import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../../public/js/modules/browser-visitors.js', import.meta.url), 'utf8');
function fixture(options = {}) {
  const calls = [];
  const handlers = {};
  const status = { textContent: '' };
  const storage = new Map(options.consent ? [['meme_explorer_visitor_consent', options.consent]] : []);
  const document = {
    visibilityState: options.hidden ? 'hidden' : 'visible',
    querySelector: selector => selector.includes('enabled') ? (options.disabled ? null : {}) : { content: 'csrf' },
    getElementById: id => id === 'visitor-privacy-status' ? status : {
      addEventListener: (event, callback) => { handlers[id] = callback; }
    },
    addEventListener: (event, callback) => { handlers[event] = callback; }
  };
  runInNewContext(source, {
    document, navigator: { globalPrivacyControl: options.gpc, doNotTrack: options.dnt },
    location: { pathname: options.path || '/random' },
    localStorage: {
      getItem: key => { if (options.storageBlocked) throw Error('blocked'); return storage.get(key); },
      setItem: (key, value) => { if (options.storageBlocked) throw Error('blocked'); storage.set(key, value); }
    },
    window: { addEventListener: (event, callback) => { handlers[event] = callback; } },
    URLSearchParams,
    fetch: async (url, args) => { calls.push({ url, args });
      if (options.fetch) return options.fetch(url, args);
      return { ok: !options.failure }; }
  });
  return { calls, handlers, status, storage, document };
}

test('collector suppresses disabled, unconsented, hidden, privacy-signaled and excluded visits', () => {
  for (const options of [{ disabled: true }, {}, { consent: 'rejected' },
    { consent: 'accepted', hidden: true }, { consent: 'accepted', gpc: true },
    { consent: 'accepted', dnt: '1' }, { consent: 'accepted', path: '/metrics' },
    { consent: 'accepted', storageBlocked: true }]) {
    assert.equal(fixture(options).calls.length, 0);
  }
});

test('privacy controls explain the saved choice and never infer deletion from rejection', () => {
  assert.match(fixture().status.textContent, /off until you choose Allow/);
  const declined = fixture({ consent: 'rejected' });
  assert.match(declined.status.textContent, /declined/);
  assert.doesNotMatch(declined.status.textContent, /Visit time and cookie cleared/);
  assert.match(fixture({ consent: 'accepted', hidden: true }).status.textContent, /consent is saved/);
  assert.match(fixture({ gpc: true }).status.textContent, /privacy signal/);
  assert.match(fixture({ storageBlocked: true }).status.textContent, /storage unavailable/);
  declined.storage.set('meme_explorer_visitor_consent', 'accepted');
  declined.document.visibilityState = 'hidden';
  declined.handlers.storage();
  assert.match(declined.status.textContent, /consent is saved/);
  assert.equal(declined.calls.length, 0);
});

test('visible opted-in page sends once despite visibility and storage events', () => {
  const f = fixture({ consent: 'accepted' });
  f.handlers.visibilitychange();
  f.handlers.storage();
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].url, '/api/visitor-observation');
  assert.equal(f.calls[0].args.headers['X-CSRF-Token'], 'csrf');
});

test('Allow respects browser privacy signals and blocked storage', () => {
  for (const options of [{ gpc: true }, { dnt: '1' }, { storageBlocked: true }]) {
    const f = fixture(options);
    f.handlers['visitor-allow']();
    assert.equal(f.calls.length, 0);
    assert.match(f.status.textContent, /privacy signal|storage unavailable/);
  }
});

test('withdrawal persists rejection and reports deletion failures without claiming success', async () => {
  const f = fixture({ consent: 'accepted', failure: true });
  await f.handlers['visitor-withdraw']();
  assert.equal(f.storage.get('meme_explorer_visitor_consent'), 'rejected');
  assert.deepEqual(f.calls.map(call => call.url), ['/api/visitor-observation', '/api/visitor-withdrawal']);
  assert.match(f.status.textContent, /Server withdrawal failed/);
  assert.doesNotMatch(f.status.textContent, /Visit time and cookie cleared/);
  f.handlers.visibilitychange();
  assert.equal(f.calls.length, 2);
});

test('observation failures do not claim recording or retry endlessly', async () => {
  for (const fetch of [async () => ({ ok: false }), async () => { throw Error('offline'); }]) {
    const f = fixture({ fetch });
    f.handlers['visitor-allow']();
    await new Promise(resolve => setImmediate(resolve));
    assert.match(f.status.textContent, /Consent saved, but measurement/);
    assert.doesNotMatch(f.status.textContent, /observation recorded/);
    f.handlers.visibilitychange();
    assert.equal(f.calls.length, 1);
  }
});

test('withdrawal waits for pending observation and its status cannot be overwritten', async () => {
  let complete;
  const f = fixture({ consent: 'accepted', fetch: url => url.endsWith('observation')
    ? new Promise(resolve => { complete = resolve; }) : Promise.resolve({ ok: true }) });
  const withdrawal = f.handlers['visitor-withdraw']();
  assert.equal(f.calls.length, 1);
  complete({ ok: true });
  await withdrawal;
  assert.match(f.status.textContent, /Visit time and cookie cleared/);
  assert.equal(f.calls.length, 2);
});

test('cross-tab withdrawal invalidates pending status even after subsequent consent changes', async () => {
  let complete;
  const f = fixture({ consent: 'accepted', fetch: () => new Promise(resolve => { complete = resolve; }) });
  f.storage.set('meme_explorer_visitor_consent', 'rejected');
  f.handlers.storage({ key: 'meme_explorer_visitor_consent' });
  assert.match(f.status.textContent, /declined/);
  f.handlers.visibilitychange();
  assert.equal(f.calls.length, 1);
  f.storage.set('meme_explorer_visitor_consent', 'accepted');
  f.handlers.storage({ key: 'meme_explorer_visitor_consent' });
  complete({ ok: true });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(f.status.textContent, /consent is saved/);
  assert.doesNotMatch(f.status.textContent, /observation recorded/);
});

test('unrelated storage events do not overwrite observation failure status', async () => {
  const f = fixture({ consent: 'accepted', failure: true });
  await new Promise(resolve => setImmediate(resolve));
  const message = f.status.textContent;
  f.handlers.storage({ key: 'unrelated-preference' });
  assert.equal(f.status.textContent, message);
  assert.match(message, /measurement is unavailable/);
});

test('revoked identity 409 explains reload-for-new-identity rather than generic unavailability', async () => {
  const f = fixture({ fetch: async () => ({ ok: false, status: 409 }) });
  f.handlers['visitor-allow']();
  await new Promise(resolve => setImmediate(resolve));
  assert.match(f.status.textContent, /withdrawn.*Reload to start a new visitor identity/);
  assert.doesNotMatch(f.status.textContent, /observation recorded|measurement is unavailable/);
});