import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const directory = process.argv[2];
const html = fs.readFileSync(directory + '/index.html', 'utf8');
const manifest = JSON.parse(fs.readFileSync(directory + '/manifest.json', 'utf8'));
const nodes = Object.fromEntries(['page','style','brightness','scale','width','scope','count'].map(k => [k, {value:'', addEventListener(){}}]));
const figures = manifest.captures.map(() => ({hidden:false}));
const sandbox = {document:{querySelectorAll:()=>figures,getElementById:k=>nodes[k]}};
vm.createContext(sandbox);
const script = html.split('<script>')[1].split('</script>')[0];
vm.runInContext(script, sandbox);
assert.equal(figures.filter(f=>!f.hidden).length, manifest.captures.length);
for (const page of ['tasks-bulk','chat','bots','more','appearance','feedback']) {
  for (const style of ['classic','liquid']) {
    nodes.page.value = page;
    nodes.style.value = style;
    vm.runInContext('update()', sandbox);
    assert.equal(figures.filter(f=>!f.hidden).length, manifest.captures.filter(c=>c.page===page && c.style===style).length);
  }
}
nodes.width.value = '999';
vm.runInContext('update()', sandbox);
assert.equal(figures.filter(f=>!f.hidden).length, 0);
assert.equal(manifest.approved, false);
nodes.width.value = '';
nodes.page.value = '';
nodes.style.value = '';
for (const scale of ['1', '2', '3']) {
  nodes.scale.value = scale;
  vm.runInContext('update()', sandbox);
  assert.equal(figures.filter(f=>!f.hidden).length, manifest.captures.filter(c=>c.scale===scale).length);
}
nodes.scale.value = '';
for (const scope of ['shell-route', 'standalone']) {
  nodes.scope.value = scope;
  vm.runInContext('update()', sandbox);
  assert.equal(figures.filter(f=>!f.hidden).length, manifest.captures.filter(c=>c.scope===scope).length);
}
assert.ok(manifest.captures.every(c=>c.scope === (c.name.startsWith('shell-') ? 'shell-route' : 'standalone')));
assert.ok(manifest.captures.every(c=>c.sha256.length===64 && c.capturedAt));
const paired = JSON.parse(fs.readFileSync(directory + '/pairs.json', 'utf8'));
const comparison = fs.readFileSync(directory + '/compare.html', 'utf8');
assert.equal(paired.approved, false);
const expected = manifest.captures.filter(c => c.brightness === 'light' && manifest.captures.some(d =>
  d.name === c.name.replace('-light-', '-dark-') && d.width === c.width && d.height === c.height));
assert.equal(paired.pairs.length, expected.length);
for (const {light, dark} of paired.pairs) {
  assert.equal(dark.name, light.name.replace('-light-', '-dark-'));
  assert.equal(light.width, dark.width);
  assert.equal(light.height, dark.height);
  for (const capture of [light, dark]) {
    assert.deepEqual(capture, manifest.captures.find(c => c.name === capture.name));
    assert.ok(comparison.includes('src="'+capture.name+'"'));
  }
}
assert.ok(html.includes('href="compare.html"'));
console.log('Exact-scene comparison pairs verified: '+paired.pairs.length);
console.log('Gallery filter logic, empty results and metadata passed (DOM stub, not browser rendering).');
