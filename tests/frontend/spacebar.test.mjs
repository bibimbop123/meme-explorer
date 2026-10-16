import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../public/js/modules/meme-navigation.js', import.meta.url), 'utf8');
const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('Space advances once from page or focused Next, without hijacking other controls', () => {
  const previous = globalThis.document;
  let loads = 0;
  let prevented = 0;
  const nav = Object.create(MemeNavigation.prototype);
  nav.loadNextMeme = () => { loads++; };
  globalThis.document = { body: { classList: { contains: () => false } }, activeElement: { tagName: 'BODY' } };
  const press = (extra = {}) => nav.handleKeyPress({ code: 'Space', preventDefault: () => { prevented++; }, ...extra });
  try {
    press();
    assert.equal(loads, 1);
    document.activeElement = { tagName: 'BUTTON', matches: () => true, disabled: false };
    press();
    press({ repeat: true });
    assert.equal(loads, 2);
    assert.equal(prevented, 3);
    document.activeElement.disabled = true;
    press();
    assert.equal(loads, 2);
    for (const tagName of ['INPUT', 'TEXTAREA', 'SELECT', 'BUTTON', 'A']) {
      document.activeElement = { tagName, matches: () => false };
      press();
    }
    document.activeElement = { tagName: 'BODY', isContentEditable: true };
    press();
    assert.equal(loads, 2);
  } finally { globalThis.document = previous; }
});