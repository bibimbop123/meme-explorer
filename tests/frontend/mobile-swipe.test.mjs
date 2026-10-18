import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/modules/mobile-swipe.js', import.meta.url), 'utf8');

function harness({ viewer = true, blocked = false, modal = false } = {}) {
  const listeners = new Map();
  const clicks = [];
  let overlays = 0;
  let clock = 0;
  const body = {
    classList: { contains: () => modal },
    appendChild(node) { overlays++; node.parentNode = { removeChild() { overlays--; } }; }
  };
  const target = { closest: selector => selector === '#meme-display' ? viewer : blocked };
  const document = {
    readyState: 'complete', body,
    getElementById: id => id === 'meme-display' ? viewer : { click: () => clicks.push(id) },
    querySelector: () => null,
    createElement: () => ({ style: {} }),
    addEventListener: (name, handler) => listeners.set(name, handler),
    removeEventListener: name => listeners.delete(name)
  };
  const window = { ontouchstart: null, location: { href: '/search' } };
  vm.runInNewContext(source, { document, window, console: { log() {} }, Date: { now: () => clock += 50 }, setTimeout: () => 0 });
  function emit(name, x, y, count = 1) {
    const touch = { clientX: x, clientY: y };
    listeners.get(name)?.({ target, touches: name === 'touchend' ? [] : Array(count).fill(touch), changedTouches: [touch], cancelable: true, preventDefault() {} });
  }
  function swipe(start = 200, end = 50) {
    emit('touchstart', start, 100);
    emit('touchmove', end, 100);
    emit('touchend', end, 100);
  }
  return { window, listeners, clicks, emit, swipe, overlays: () => overlays };
}

test('swipes do not initialize on unrelated pages or navigate away', () => {
  const h = harness({ viewer: false });
  h.swipe();
  assert.equal(h.listeners.size, 0);
  assert.equal(h.overlays(), 0);
  assert.equal(h.window.location.href, '/search');
});

test('horizontal viewer swipes navigate once, including touches starting at x=0', () => {
  const h = harness();
  h.swipe();
  h.swipe(0, 160);
  assert.deepEqual(h.clicks, ['next-btn', 'prev-btn']);
});

test('interactive media, galleries and modal content retain their gestures', () => {
  for (const options of [{ blocked: true }, { modal: true }]) {
    const h = harness(options);
    h.swipe();
    assert.deepEqual(h.clicks, []);
  }
});

test('pinch, cancellation and vertical scrolling never turn into feed navigation', () => {
  const h = harness();
  h.emit('touchstart', 200, 100);
  h.emit('touchmove', 100, 100, 2);
  h.emit('touchend', 20, 100);
  h.emit('touchstart', 200, 100);
  h.emit('touchmove', 100, 100);
  h.emit('touchcancel', 100, 100);
  h.emit('touchend', 20, 100);
  h.emit('touchstart', 200, 100);
  h.emit('touchmove', 170, 140);
  h.emit('touchmove', 20, 140);
  h.emit('touchend', 20, 140);
  assert.deepEqual(h.clicks, []);
});

test('initialization is idempotent and destroy removes all gesture listeners', () => {
  const h = harness();
  h.window.mobileSwipe.init();
  assert.equal(h.overlays(), 1);
  assert.equal(h.listeners.size, 4);
  h.window.mobileSwipe.destroy();
  assert.equal(h.listeners.size, 0);
  assert.equal(h.overlays(), 0);
  h.window.mobileSwipe.init();
  h.swipe();
  assert.deepEqual(h.clicks, ['next-btn']);
});