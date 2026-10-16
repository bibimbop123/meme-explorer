import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../public/js/saved-media-recovery.js', import.meta.url), 'utf8');
function setup({ complete = false, safe = true } = {}) {
  const events = {};
  let click;
  let requests = 0;
  const image = {
    dataset: { savedMedia: safe ? 'available' : 'unavailable' }, complete, naturalWidth: 0,
    addEventListener: (event, fn) => { events[event] = fn; },
    getAttribute: () => 'https://i.redd.it/original.jpg',
    set src(value) { assert.equal(value, 'https://i.redd.it/original.jpg'); requests++; }
  };
  const recovery = { hidden: true };
  const status = {};
  const retry = { disabled: false, addEventListener: (_, fn) => { click = fn; } };
  vm.runInNewContext(source, { document: {
    querySelector: () => image,
    getElementById: id => ({ 'saved-media-recovery': recovery, 'saved-media-status': status, 'retry-saved-media': safe ? retry : null })[id]
  } });
  return { image, recovery, status, retry, events, click, requests: () => requests };
}

test('Saved image handles failure before script initialization', () => {
  const state = setup({ complete: true });
  assert.equal(state.image.hidden, true);
  assert.equal(state.recovery.hidden, false);
  assert.match(state.status.textContent, /still saved/);
});

test('Saved retry is explicit, blocks duplicates, and permits retry after failure', () => {
  const state = setup();
  state.events.error();
  state.click();
  state.click();
  assert.equal(state.requests(), 1);
  assert.equal(state.retry.disabled, true);
  state.events.error();
  assert.equal(state.retry.disabled, false);
  state.click();
  assert.equal(state.requests(), 2);
  state.events.load();
  assert.equal(state.image.hidden, false);
  assert.equal(state.status.textContent, 'Image loaded.');
  assert.equal(state.retry.disabled, false);
});

test('Saved normal image load hides the recovery UI', () => {
  const state = setup();
  state.events.load();
  assert.equal(state.recovery.hidden, true);
});

test('Unsafe Saved media has no retry or source request', () => {
  const state = setup({ safe: false });
  assert.equal(state.recovery.hidden, false);
  assert.equal(state.image.hidden, true);
  assert.equal(state.requests(), 0);
  assert.equal(state.click, undefined);
});