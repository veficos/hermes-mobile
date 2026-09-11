// Use an isolated Chromium profile with --remote-debugging-port=9223.
// This changes preferences only in that browser, never the app source.
import {writeFile} from 'node:fs/promises';

const pages = await (await fetch('http://127.0.0.1:9223/json')).json();
const page = pages.find(p => p.type === 'page' && p.url.startsWith('http://127.0.0.1:9000/'));
if (!page) throw new Error('Open port 9000 in the isolated debug browser first');
const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.onopen = resolve;
  socket.onerror = reject;
});
let serial = 0;
const pending = new Map();
socket.onmessage = event => {
  const message = JSON.parse(event.data);
  const request = pending.get(message.id);
  if (request) {
    pending.delete(message.id);
    message.error ? request.reject(message.error) : request.resolve(message.result);
  }
};
function command(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++serial;
    pending.set(id, {resolve, reject});
    socket.send(JSON.stringify({id, method, params}));
  });
}
try {
  await command('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 844, deviceScaleFactor: 1, mobile: true,
  });
  await command('Runtime.evaluate', {expression:
    "localStorage.setItem('flutter.hm_visual_style', JSON.stringify('liquid'))"});
  await command('Page.reload');
  await new Promise(resolve => setTimeout(resolve, 8000));
  const preference = await command('Runtime.evaluate', {expression:
    "localStorage.getItem('flutter.hm_visual_style')", returnByValue: true});
  console.log('Liquid preference:', preference.result.value);
  // Flutter paints on canvas; activate its accessibility tree to identify
  // the route and visible controls independently of screenshot display.
  await command('Runtime.evaluate', {expression:
    "document.querySelector('flt-semantics-placeholder')?.click()"});
  await new Promise(resolve => setTimeout(resolve, 1000));
  const semantics = await command('Runtime.evaluate', {expression:
    "document.body.innerText", returnByValue: true});
  console.log('Visible semantics:', semantics.result.value);
  const screenshot = await command('Page.captureScreenshot', {format: 'png'});
  const path = process.argv[2] ?? '/tmp/hermes-liquid-phone.png';
  await writeFile(path, Buffer.from(screenshot.data, 'base64'));
  console.log('Captured:', path);
} finally {
  socket.close();
}
