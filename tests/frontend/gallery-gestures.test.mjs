import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const navigation = await readFile(new URL('../../public/js/modules/meme-navigation.js', import.meta.url), 'utf8');
const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(navigation).toString('base64')}`);
const helper = await readFile(new URL('../../lib/helpers/gallery_helpers.rb', import.meta.url), 'utf8');
const script = helper.split('  def gallery_script')[1].split('<script>')[1].split('</script>')[0];

for (const kind of ['server', 'dynamic']) {
  test(`${kind} gallery ignores vertical, pinch and canceled gestures but accepts horizontal swipe`, () => {
    const events = {};
    let index = 0;
    const target = { closest: selector => selector === '.meme-gallery' };
    const gallery = {
      dataset: {},
      addEventListener: (name, handler) => { events[name] = handler; },
      querySelectorAll: selector => Array.from({ length: 3 }, (_, i) => ({
        style: {}, setAttribute() {},
        classList: { remove() {}, add() { if (selector === '.gallery-slide') index = i; } },
        addEventListener() {}
      })),
      querySelector: () => ({ addEventListener() {}, textContent: '' })
    };
    const document = {
      querySelector: () => gallery,
      querySelectorAll: () => [gallery],
      addEventListener: (_, ready) => ready(),
      dispatchEvent() {}
    };
    if (kind === 'server') {
      vm.runInNewContext(script, { document, CustomEvent: class {} });
    } else {
      const previous = globalThis.document;
      globalThis.document = document;
      try {
        MemeNavigation.prototype.bindGalleryControls.call({
          nextGalleryImage: () => { index++; }, prevGalleryImage: () => { index--; }
        });
      } finally { globalThis.document = previous; }
    }
    const emit = (name, x, y, count = 1) => events[name]?.({
      target, touches: name === 'touchend' ? [] : Array(count).fill({ clientX: x, clientY: y }),
      changedTouches: [{ clientX: x, clientY: y }]
    });
    emit('touchstart', 200, 200);
    emit('touchmove', 120, 20);
    emit('touchend', 120, 20);
    assert.equal(index, 0);
    emit('touchstart', 200, 200);
    emit('touchmove', 100, 200, 2);
    emit('touchend', 20, 200);
    assert.equal(index, 0);
    emit('touchstart', 200, 200);
    emit('touchcancel', 20, 200);
    emit('touchend', 20, 200);
    assert.equal(index, 0);
    emit('touchstart', 200, 200);
    emit('touchmove', 20, 200);
    emit('touchend', 20, 200);
    assert.equal(index, 1);
  });
}