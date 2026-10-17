import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../public/js/web-vitals.js', import.meta.url), 'utf8');

test('vitals remain local and never POST browsing paths to an unsupported endpoint', () => {
  const observers = new Map();
  const listeners = [];
  const requests = [];
  class PerformanceObserver {
    constructor(callback) { this.callback = callback; }
    observe({ type }) { observers.set(type, this.callback); }
  }
  const window = {
    PerformanceObserver,
    location: { pathname: '/meme/private-browsing-path' },
    addEventListener: (...args) => listeners.push(args)
  };
  vm.runInNewContext(source, {
    window, PerformanceObserver, console: { log() {}, warn() {}, error() {} },
    fetch: (...args) => { requests.push(args); return Promise.resolve({ ok: false }); }
  });
  observers.get('largest-contentful-paint')({ getEntries: () => [{ renderTime: 1400 }] });
  observers.get('first-input')({ getEntries: () => [{ processingStart: 105, startTime: 100 }] });
  observers.get('layout-shift')({ getEntries: () => [{ hadRecentInput: false, value: 0.04 }] });
  assert.equal(window.getWebVitals().lcp, 1400);
  assert.equal(window.getWebVitals().fid, 5);
  assert.equal(window.getWebVitals().cls, 0.04);
  assert.equal(requests.length, 0);
  assert.equal(listeners.length, 0);
});

test('local diagnostics remain available when PerformanceObserver is unsupported', () => {
  const window = {};
  vm.runInNewContext(source, { window, console: { warn() {} } });
  assert.equal(window.getWebVitals().lcp, null);
});