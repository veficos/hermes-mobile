// Usage: node tool/build_ui_review.mjs CAPTURE_DIR OUTPUT_DIR
import { readdir, mkdir, copyFile, writeFile, readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
const [source, destination] = process.argv.slice(2);
if (!source || !destination) throw new Error('Expected capture and output directories');
const files = (await readdir(source)).filter(name => /^(bots|tasks|tasks-board|more|chat|appearance|shell|feedback)-[a-z0-9.-]+[.]png$/.test(name)).sort();
if (!files.length) throw new Error('No core-page PNG captures found');
await mkdir(destination, { recursive: true });
const captures = [];
for (const name of files) {
  const data = await readFile(path.join(source, name));
  if (data.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('Invalid PNG: ' + name);
  const width = data.readUInt32BE(16), height = data.readUInt32BE(20);
  await copyFile(path.join(source, name), path.join(destination, name));
  const brightness = name.includes('-dark-') ? 'dark' : 'light';
  const style = name.includes('-classic-') ? 'classic' : 'liquid';
  const pageName = name.replace(/^shell-/, '');
  const page = pageName.startsWith('tasks-bulk-') ? 'tasks-bulk' : pageName.startsWith('tasks-board-') ? 'tasks-board' : pageName.split('-')[0];
  const scope = name.startsWith('shell-') ? 'shell-route' : 'standalone';
  const scale = name.includes('-3.0') ? '3' : name.includes('-2.0') ? '2' : '1';
  const capturedAt = (await stat(path.join(source, name))).mtime.toISOString();
  captures.push({ name, width, height, brightness, style, page, scope, scale, capturedAt, sha256: createHash('sha256').update(data).digest('hex') });
}
const generated = new Date().toISOString();
// Pair exact scene/viewport/scale counterparts, without implying approval.
const pairs = captures.filter(c => c.brightness === 'light').flatMap(light => {
  const dark = captures.find(c => c.name === light.name.replace('-light-', '-dark-'));
  return dark && dark.width === light.width && dark.height === light.height
    ? [{light, dark}] : [];
});
await writeFile(path.join(destination, 'pairs.json'), JSON.stringify({approved: false, pairs}, null, 2));
const pairedCards = pairs.map(({light, dark}) => '<section><h2>'+light.name.replace('-light-', '-paired-')+'</h2><div>'+[light,dark].map(c => '<figure><a href="'+c.name+'"><img loading="lazy" src="'+c.name+'" width="'+c.width+'" height="'+c.height+'" alt="'+c.name+'"></a><figcaption>'+c.name+'<br>'+c.capturedAt+'</figcaption></figure>').join('')+'</div></section>').join('');
await writeFile(path.join(destination, 'compare.html'), '<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hermes 明暗对照</title><style>body{margin:20px;background:#eceef2;color:#18212e;font:16px/1.6 system-ui}h2{font-size:18px;overflow-wrap:anywhere}section>div{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}section{max-width:1600px;margin:32px auto}figure{margin:0}img{max-width:100%;height:auto}figcaption{overflow-wrap:anywhere}a{display:inline-block;min-height:44px}</style><h1>同场景明暗对照 · 待审核</h1><a href="index.html">返回筛选画廊</a><p>左浅色、右深色；点击查看原尺寸。仅配对同场景、尺寸和字号截图。检查文字、留白与材质层次，不代表与 iOS 参考图对照或视觉批准。</p>'+pairedCards+'</html>');
const filters = '<nav aria-label="截图筛选"><label>页面 <select id="page"><option value="">全部</option><option>bots</option><option>chat</option><option>tasks</option><option>tasks-board</option><option>tasks-bulk</option><option>more</option></select></label> <label>风格 <select id="style"><option value="">全部</option><option>classic</option><option>liquid</option></select></label> <label>明暗 <select id="brightness"><option value="">全部</option><option>light</option><option>dark</option></select></label> <label>字号 <select id="scale"><option value="">全部</option><option value="1">1×</option><option value="2">2×</option></select></label> <label>宽度 <select id="width"><option value="">全部</option><option>320</option><option>390</option><option>430</option><option>768</option><option>1280</option></select></label><p id="count" role="status"></p></nav>';
const filterScript = '<script>const data='+JSON.stringify(captures)+';const keys=["page","style","brightness","scale","width"];const figures=[...document.querySelectorAll("figure")];function update(){let count=0;figures.forEach((figure,i)=>{const visible=keys.every(key=>!document.getElementById(key).value||String(data[i][key])===document.getElementById(key).value);figure.hidden=!visible;if(visible)count++});document.getElementById("count").textContent="显示 "+count+" / "+data.length+" 张"}keys.forEach(key=>document.getElementById(key).addEventListener("change",update));update();</script>';
const cards = captures.map(({name,width,height}) => '<figure><a href="'+name+'"><img loading="lazy" src="'+name+'" width="'+width+'" height="'+height+'" alt="'+name+'"></a><figcaption>'+name+'<br>'+width+' × '+height+'</figcaption></figure>').join('');
await writeFile(path.join(destination, 'manifest.json'), JSON.stringify({ generated, captures, approved: false }, null, 2));
await writeFile(path.join(destination, 'index.html'), '<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hermes UI 待审核截图</title><style>body{margin:24px;background:#eceef2;color:#18212e;font:16px/1.6 system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}figure{margin:0;padding:12px;background:white;border-radius:16px}img{max-width:100%;height:auto;display:block;margin:auto}figcaption{overflow-wrap:anywhere;margin-top:12px}header{max-width:960px;margin-bottom:24px}</style><header><h1>Hermes UI 待审核截图</h1><p>生成时间 '+generated+' · '+captures.length+' 张。点击图片查看原尺寸。文件名标明明暗、字号倍率和宽度；未标宽度的为 320px。</p><p>这些是受控数据的 Flutter 页面截图，不包含真实系统状态栏、系统键盘或实时网关。Bots / Tasks / More 不包含应用底部导航；Chat 包含审批与输入框。它们不是已批准的视觉基线，也不代表 iOS 原生材质验收。</p><p>审核重点：文字可读性、操作层级、头像与文本对齐、明暗材质、窄屏大字溢出。当前审核状态：待确认。</p></header><main>'+cards+'</main></html>');
console.log('Generated '+captures.length+' review captures in '+destination);
const indexPath = path.join(destination, 'index.html');
const html = await readFile(indexPath, 'utf8');
const scopedFilters = filters
  .replace('<option>2</option>', '<option>2</option><option>3</option>')
  .replace('<option>more</option>', '<option>feedback</option><option>more</option>')
  .replace('<option>768</option>', '<option>768</option><option>900</option>')
  .replace('<option>more</option>', '<option>more</option><option>appearance</option>')
  .replace('</nav>', '<label>场景 <select id="scope"><option value="">全部</option><option value="shell-route">真实应用导航／路由</option><option value="standalone">独立页面／组件</option></select></label></nav>');
const scopedScript = filterScript.replace('const keys=[', 'const keys=["scope",');
const scopedHtml = html.replace(
  'Bots / Tasks / More 不包含应用底部导航；Chat 包含审批与输入框。',
  'shell-* 截图通过真实 AppShell 导航进入页面；shell-chat 是实际推入的聊天路由，不显示底部导航。其他截图为独立页面或组件，其中独立 Chat 场景包含审批与输入框。不同场景不应直接作为像素差异对照。',
);
const comparisonLink = '<a href="compare.html">打开同场景明暗对照</a>';
await writeFile(indexPath, scopedHtml.replace('</style>', 'select{min-height:44px;font:inherit;margin:4px}figure[hidden]{display:none}</style>').replace('<main>', scopedFilters+'<main>').replace('</html>', scopedScript+'</html>'));
await writeFile(indexPath, (await readFile(indexPath, 'utf8')).replace('<h1>', comparisonLink+'<h1>'));
