// يبني صفحة واحدة مستقلة (dist/artifact.html) من ملفات المشروع: CSS وJS والبيانات مدمجة.
// تشغيل: node build.mjs
import fs from 'node:fs';

const read = (p) => fs.readFileSync(new URL(p, import.meta.url), 'utf8');

// ترتيب الوحدات حسب الاعتماد
const MODULES = [
  ['categories', 'js/categories.js'],
  ['calc', 'js/calc.js'],
  ['foods', 'data/foods.js'],
  ['ui', 'js/ui.js'],
  ['db', 'js/db.js'],
  ['app', 'js/app.js'],
];

function bundleModule(name, src) {
  const exported = [];
  // import { a, b } from './x.js'   (قد يمتد على عدة أسطر)
  src = src.replace(/import\s*\{([^}]*)\}\s*from\s*['"]([^'"]+)['"];?/g, (_, names, from) =>
    `const {${names}} = __m[${JSON.stringify(modName(from))}];`);
  src = src.replace(/import\s*\*\s*as\s+(\w+)\s+from\s*['"]([^'"]+)['"];?/g, (_, alias, from) =>
    `const ${alias} = __m[${JSON.stringify(modName(from))}];`);
  src = src.replace(/^export\s+(async\s+function|function|const|let|class)\s+(\w+)/gm, (_, kind, id) => {
    exported.push(id);
    return `${kind} ${id}`;
  });
  if (/^\s*(import|export)\s/m.test(src)) throw new Error(`صيغة import/export غير مدعومة في ${name}`);
  return `__m[${JSON.stringify(name)}] = (() => {\n${src}\nreturn { ${exported.join(', ')} };\n})();`;
}

function modName(from) {
  return from.split('/').pop().replace(/\.js$/, '');
}

const js = `(() => {\n'use strict';\nconst __m = {};\n${MODULES.map(([n, p]) => bundleModule(n, read(p))).join('\n\n')}\n})();`;
const css = read('css/styles.css');
const iconSvg = read('icons/icon.svg').trim();
const iconUri = `data:image/svg+xml;base64,${Buffer.from(iconSvg).toString('base64')}`;

// محتوى الصفحة بين <body> و</body> مع استبدال سكربت الوحدة
const html = read('index.html');
let body = html.slice(html.indexOf('<body>') + 6, html.indexOf('</body>'));
body = body
  .replace(/<script type="module"[^>]*><\/script>/, '')
  .replace('src="icons/icon.svg"', `src="${iconUri}"`);

const out = `<title>حاسبة الكربوهيدرات والإنسولين</title>
<meta name="claude:viewport-fit-sides" content="cover">
<meta name="description" content="احسب كربوهيدرات وجبتك والناتج الحسابي لجرعة الإنسولين">
<style>
html { direction: rtl; }
${css}
</style>
<div dir="rtl" lang="ar">
${body.trim()}
</div>
<script>
document.documentElement.lang = 'ar';
document.documentElement.dir = 'rtl';
${js}
</script>
`;

fs.mkdirSync(new URL('dist/', import.meta.url), { recursive: true });
fs.writeFileSync(new URL('dist/artifact.html', import.meta.url), out);
console.log(`dist/artifact.html — ${(out.length / 1024).toFixed(1)} KB`);
