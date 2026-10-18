import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/layout-utils.js', import.meta.url), 'utf8');
test('skip focuses and scrolls main without fragment navigation or a permanent Tab stop', () => {
  let click;
  let prevented = false;
  let focused = false;
  let scrolled = false;
  const main = {
    focus(options) { assert.equal(options.preventScroll, true); focused = true; },
    scrollIntoView(options) { assert.equal(options.block, 'start'); scrolled = true; }
  };
  vm.runInNewContext(source, { document: {
    readyState: 'loading', addEventListener() {},
    querySelector: () => ({ addEventListener: (_, handler) => { click = handler; } }),
    getElementById: () => main
  } });
  click({ preventDefault: () => { prevented = true; } });
  assert.ok(prevented && focused && scrolled);
});