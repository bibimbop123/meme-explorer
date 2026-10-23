// Isolated browser_fixture.ru with ENABLE_VISITOR_METRICS=true; disposable CDP.
import assert from 'node:assert/strict';
const origin = 'http://127.0.0.1:19292';
const tabs = [];
async function tab() {
  const target = await (await fetch('http://127.0.0.1:19293/json/new?about:blank', { method: 'PUT' })).json();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise(resolve => ws.addEventListener('open', resolve, { once: true }));
  let id = 0;
  const pending = new Map();
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const key = ++id;
    const timer = setTimeout(() => { pending.delete(key); reject(Error(`Timeout: ${method}`)); }, 10000);
    pending.set(key, { resolve, reject, timer });
    ws.send(JSON.stringify({ id: key, method, params }));
  });
  let observations = 0;
  ws.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const item = pending.get(message.id);
      if (!item) return;
      pending.delete(message.id); clearTimeout(item.timer);
      message.error ? item.reject(Error(JSON.stringify(message.error))) : item.resolve(message.result);
    } else if (message.method === 'Fetch.requestPaused') {
      const { requestId, request } = message.params;
      if (request.url === `${origin}/api/visitor-observation`) observations++;
      const allowed = request.url.startsWith(`${origin}/`) || request.url.startsWith('data:');
      send(allowed ? 'Fetch.continueRequest' : 'Fetch.failRequest', allowed ? { requestId } : { requestId, errorReason: 'BlockedByClient' }).catch(() => {});
    }
  };
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    assert.equal(result.exceptionDetails, undefined);
    return result.result.value;
  };
  const wait = async expression => {
    for (let i = 0; i < 80; i++) {
      if (await evaluate(expression)) return;
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw Error(`Condition timeout: ${expression}`);
  };
  const result = { target, ws, send, evaluate, wait, observations: () => observations,
    close: async () => {
      try { await send('Page.close'); } finally {
        for (const item of pending.values()) clearTimeout(item.timer);
        ws.close();
      }
    } };
  tabs.push(result);
  await send('Page.enable');
  await send('Fetch.enable', { patterns: [{ urlPattern: '*' }] });
  return result;
}
const check = (label, value) => { assert.ok(value, label); console.log(`PASS: ${label}`); };
try {
  const first = await tab();
  await first.send('Storage.clearDataForOrigin', { origin, storageTypes: 'all' });
  await first.send('Page.navigate', { url: `${origin}/random` });
  await first.wait(`document.readyState==='complete' && !!document.querySelector('#visitor-allow')`);
  await first.evaluate(`document.querySelector('#visitor-allow').click()`);
  await first.wait(`document.querySelector('#visitor-privacy-status').textContent.includes('observation recorded')`);
  const cookies = async page => (await page.send('Network.getCookies', { urls: [origin] })).cookies.filter(c => c.name === 'meme_visitor');
  const identity = (await cookies(first))[0]?.value;
  check('first tab establishes visitor identity', !!identity);
  const second = await tab();
  await second.send('Page.navigate', { url: `${origin}/random` });
  await second.wait(`document.querySelector('#visitor-privacy-status')?.textContent.includes('observation recorded')`);
  check('second tab shares established identity', (await cookies(second))[0]?.value === identity);
  const before = second.observations();
  await first.evaluate(`document.querySelector('#visitor-withdraw').click()`);
  await first.wait(`document.querySelector('#visitor-privacy-status').textContent.includes('Visit time and cookie cleared')`);
  await second.wait(`document.querySelector('#visitor-privacy-status').textContent.includes('declined')`);
  check('second tab receives withdrawal storage event', await second.evaluate(`localStorage.getItem('meme_explorer_visitor_consent')==='rejected'`));
  check('withdrawal removes shared cookie', (await cookies(second)).length === 0);
  await second.send('Page.bringToFront');
  await second.evaluate(`document.dispatchEvent(new Event('visibilitychange'))`);
  await new Promise(resolve => setTimeout(resolve, 300));
  check('visibility after withdrawal issues no observation', second.observations() === before);
} finally {
  for (const page of tabs.reverse()) await page.close().catch(() => {});
}