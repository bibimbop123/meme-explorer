import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/dark-mode.js', import.meta.url), 'utf8');
function setup({ legacy, dark = false, blocked = false } = {}) {
  const values = {};
  let click;
  let changed;
  const root = { setAttribute: (key, value) => { values[key] = value; }, getAttribute: key => values[key], classList: { toggle: (_name, value) => { values.darkClass = value; } } };
  const button = { setAttribute: (key, value) => { values[key] = value; }, addEventListener: (_name, callback) => { click = callback; } };
  const system = { matches: dark, addEventListener: (_name, callback) => { changed = callback; } };
  vm.runInNewContext(source, {
    document: { documentElement: root, readyState: 'complete', getElementById: () => button, addEventListener() {} },
    window: { matchMedia: () => system },
    localStorage: { getItem: key => { if (blocked) throw new Error('blocked'); return key === 'theme' ? legacy : null; }, setItem() { if (blocked) throw new Error('blocked'); } }
  });
  return { values, click: () => click(), change: value => { system.matches = value; changed(); } };
}
test('theme keeps CSS class and data attribute synchronized with legacy preference', () => {
  const app = setup({ legacy: 'dark' });
  assert.equal(app.values.darkClass, true);
  app.click();
  assert.equal(app.values['data-theme'], 'light');
  assert.equal(app.values.darkClass, false);
  assert.equal(app.values['aria-pressed'], 'false');
});
test('storage restrictions do not disable theme controls', () => {
  const app = setup({ blocked: true, dark: true });
  app.click();
  assert.equal(app.values['data-theme'], 'light');
});
test('system changes apply until the user chooses a theme', () => {
  const app = setup();
  app.change(true);
  assert.equal(app.values['data-theme'], 'dark');
  app.click();
  app.change(true);
  assert.equal(app.values['data-theme'], 'light');
});