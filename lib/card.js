// تصميم بطاقة التشكيلة (HTML) وتحويلها لصورة PNG باستخدام Chrome
import fs from 'node:fs';
import { chromium } from 'playwright-core';
import { config, env, fmtTime, fmtDate, ROOT } from './config.js';

// الخط مضمّن داخل الصورة مباشرة (ما يحتاج إنترنت)
const FONT_FILE = new URL(config.fontFile || 'assets/fonts/thmanyah-serif-display-bold.otf', ROOT);
const FONT_CSS = fs.existsSync(FONT_FILE)
  ? `@font-face{font-family:'CardFont';src:url(data:font/otf;base64,${fs.readFileSync(FONT_FILE).toString('base64')}) format('opentype');font-weight:100 900;font-display:block}`
  : '';

const escN = (s) => esc(s).replace(/(\d+)\s*([-–])\s*(\d+)/g, '<span dir="ltr" style="unicode-bidi:isolate">$1$2$3</span>');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// الشعار داخل الدائرة البيضاء (بدون أي حرف بديل). لو ما توفر الشعار تختفي الدائرة
const crest = (src) => (src ? `<div class="crest"><img src="${esc(src)}" onerror="this.parentNode.remove()"></div>` : '');

const MIME = { png: 'image/png', svg: 'image/svg+xml', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif' };

// يحمّل الشعار ويحوّله لبيانات مضمّنة في الصورة (رابط أو ملف محلي داخل مجلد البوت)
export async function crestData(src) {
  if (!src) return null;
  if (src.startsWith('data:')) return src;
  try {
    let buf, type;
    if (/^https?:/.test(src)) {
      const res = await fetch(src, { signal: AbortSignal.timeout(10000), headers: { 'User-Agent': 'Mozilla/5.0' } });
      if (!res.ok) throw new Error(res.status);
      buf = Buffer.from(await res.arrayBuffer());
      type = res.headers.get('content-type')?.split(';')[0];
    } else {
      buf = fs.readFileSync(new URL(src, ROOT));
    }
    type = type?.startsWith('image/') ? type : MIME[src.split('.').pop().toLowerCase()] || 'image/png';
    return `data:${type};base64,${buf.toString('base64')}`;
  } catch (e) {
    console.warn(`⚠️ تعذر تحميل الشعار ${src}: ${e.message}`);
    return null;
  }
}

// lines: [[حارس], [دفاع يسار←يمين], [وسط], [هجوم]] — كل لاعب {name, number}
function pitchPlayers(lines) {
  const n = lines.length;
  return lines.map((line, i) => {
    const top = i === 0 ? 88 : 69 - ((i - 1) * 56) / Math.max(n - 2, 1); // الحارس تحت والهجوم فوق
    return line.map((p, j) => {
      const left = ((j + 1) / (line.length + 1)) * 100;
      return `<div class="player" style="top:${top}%;left:${left}%">
        <div class="shirt"><b>${esc(p.number ?? '')}</b></div>
        <div class="pname">${esc(p.name)}</div>
      </div>`;
    }).join('');
  }).join('');
}

export function lineupHtml(d) {
  const subs = (d.subs || []).map((p) =>
    `<span class="sub"><i>${esc(p.number ?? '')}</i>${esc(p.name)}</span>`).join('');
  const when = `${fmtDate(d.kickoff)} · ${fmtTime(d.kickoff)} ${esc(config.timezoneLabel || '')}`;
  const [home, away] = d.isHome
    ? [{ name: 'ريال مدريد', crest: d.rmCrest }, { name: d.opponentAr, crest: d.opponentCrest }]
    : [{ name: d.opponentAr, crest: d.opponentCrest }, { name: 'ريال مدريد', crest: d.rmCrest }];

  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
${FONT_CSS}
:root{--navy:#070b1f;--ink:#0d1433;--gold:#e3b54a;--gold2:#fff1c4;--violet:#6a35b5;--white:#f7f8fc}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1350px;overflow:hidden}
.deco{position:absolute;inset:0;overflow:hidden}
body{font-family:'CardFont','DejaVu Sans',sans-serif;font-synthesis:none;color:var(--white);background:var(--navy);position:relative;overflow:hidden}
.bg{position:absolute;inset:0;
  background:
    radial-gradient(900px 600px at 105% -10%, rgba(106,53,181,.55), transparent 60%),
    radial-gradient(700px 500px at -10% 110%, rgba(227,181,74,.22), transparent 60%),
    repeating-linear-gradient(-55deg, rgba(255,255,255,.025) 0 2px, transparent 2px 26px),
    linear-gradient(180deg,#0a1030,#060918)}
.slash{position:absolute;top:-40px;left:-60px;width:340px;height:1350px;background:linear-gradient(180deg,rgba(227,181,74,.16),rgba(227,181,74,0));transform:skewX(-14deg)}
.wrap{position:relative;padding:44px 60px 0;height:100%}
.top{display:flex;justify-content:space-between;align-items:center}
.comp{border:2px solid var(--gold);color:var(--gold2);border-radius:999px;padding:6px 24px;font-weight:700;font-size:24px;background:rgba(227,181,74,.08)}
.form{font-weight:900;font-size:26px;color:var(--navy);background:var(--gold);border-radius:12px;padding:4px 18px;letter-spacing:1px;direction:ltr;unicode-bidi:isolate}
h1{font-size:88px;font-weight:900;line-height:1.05;margin-top:14px;letter-spacing:-1px}
h1 em{font-style:normal;color:var(--gold)}
.match{display:flex;align-items:center;justify-content:center;gap:22px;margin-top:14px}
.team{display:flex;align-items:center;gap:14px;font-size:34px;font-weight:900}
.vs{font-size:56px;line-height:1;color:var(--gold);font-weight:900;padding:0 10px;font-family:'DejaVu Sans',sans-serif}
.crest{width:84px;height:84px;flex:none;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:0 6px 18px rgba(0,0,0,.4),0 0 0 3px rgba(227,181,74,.6)}
.crest img{width:70%;height:70%;object-fit:contain}
.when{text-align:center;color:#c9cde0;font-size:22px;font-weight:500;margin-top:6px}
.pitch{position:relative;margin:22px auto 0;width:960px;height:770px;border-radius:30px;overflow:hidden;
  background:repeating-linear-gradient(180deg,#1d6a3c 0 72px,#207444 72px 144px);
  box-shadow:inset 0 0 120px rgba(0,0,0,.55),0 20px 50px rgba(0,0,0,.5);border:3px solid rgba(227,181,74,.55)}
.ln{position:absolute;border:3px solid rgba(255,255,255,.35)}
.player{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;width:200px}
.shirt{width:84px;height:84px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#fff,#e9ebf3);border:5px solid var(--gold);display:grid;place-items:center;box-shadow:0 8px 18px rgba(0,0,0,.45)}
.shirt b{color:var(--ink);font-size:36px;font-weight:900;direction:ltr;unicode-bidi:isolate}
.pname{margin-top:8px;background:rgba(7,11,31,.88);border:1px solid rgba(227,181,74,.45);padding:0 14px 4px;border-radius:10px;font-size:25px;font-weight:700;max-width:200px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bench{margin-top:20px}
.bench h3{font-size:24px;color:var(--gold);font-weight:900;margin-bottom:8px}
.subs{display:flex;flex-wrap:wrap;gap:8px}
.sub{background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);border-radius:10px;padding:2px 12px;font-size:20px;font-weight:700}
.sub i{font-style:normal;color:var(--gold);margin-left:8px;direction:ltr;unicode-bidi:isolate;display:inline-block}
.foot{position:absolute;bottom:26px;right:60px;left:60px;display:flex;justify-content:space-between;font-size:22px;color:#aeb3cc;font-weight:700}
.foot .coach b{color:var(--white)}
</style></head><body>
<div class="deco"><div class="bg"></div><div class="slash"></div></div>
<div class="wrap">
  <div class="top"><span class="comp">${esc(d.competitionAr)}</span>${d.formation ? `<span class="form">${esc(d.formation)}</span>` : ''}</div>
  <h1>التشكيلة <em>الرسمية</em></h1>
  <div class="match">
    <div class="team">${crest(home.crest)}<span>${esc(home.name)}</span></div>
    <span class="vs">×</span>
    <div class="team"><span>${esc(away.name)}</span>${crest(away.crest)}</div>
  </div>
  <div class="when">${when}${d.venue ? ` · ${esc(d.venue)}` : ''}</div>
  <div class="pitch">
    <div class="ln" style="inset:22px"></div>
    <div class="ln" style="left:22px;right:22px;top:50%;height:0;border-width:3px 0 0"></div>
    <div class="ln" style="left:50%;top:50%;width:170px;height:170px;border-radius:50%;transform:translate(-50%,-50%)"></div>
    <div class="ln" style="left:50%;top:22px;width:420px;height:120px;transform:translateX(-50%);border-top:0"></div>
    <div class="ln" style="left:50%;bottom:22px;width:420px;height:120px;transform:translateX(-50%);border-bottom:0"></div>
    <div class="ln" style="left:50%;bottom:22px;width:180px;height:48px;transform:translateX(-50%);border-bottom:0"></div>
    ${pitchPlayers(d.lines)}
  </div>
  ${subs ? `<div class="bench"><h3>الاحتياط</h3><div class="subs">${subs}</div></div>` : ''}
</div>
<div class="foot">
  <span class="coach">${d.coachAr ? `المدرب: <b>${esc(d.coachAr)}</b>` : ''}</span>
  <span>${[config.handle, '#ريال_مدريد'].filter(Boolean).map((x) => `<bdi>${esc(x)}</bdi>`).join(' · ')}</span>
</div>
</body></html>`;
}

export async function renderPng(html, { width = 1080, height = 1350 } = {}) {
  const opts = env.CHROME_PATH ? { executablePath: env.CHROME_PATH } : { channel: 'chrome' };
  const browser = await chromium.launch({ ...opts, timeout: 60000 });
  try {
    const page = await browser.newPage({ viewport: { width, height } });
    await page.setContent(html, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
    await Promise.race([page.evaluate(() => document.fonts.ready), new Promise((r) => setTimeout(r, 10000))]);
    return await page.screenshot({ type: 'png' });
  } finally {
    await browser.close();
  }
}

// بطاقة النتيجة النهائية (1080×1080)
// d: { competitionAr, kickoff, result, home:{name, crest, score, scorers:[{name,min,note}]}, away:{...} }
export function resultHtml(d) {
  const scorers = (list) => list.map((g) =>
    `<li><span class="ball">⚽</span><b>${esc(g.name)}</b>${g.note ? ` <i>${esc(g.note)}</i>` : ''}<em>${esc(g.min)}'</em></li>`).join('');
  const side = (t) => `
    <div class="side">
      <div class="big-crest">${t.crest ? `<img src="${esc(t.crest)}" onerror="this.remove()">` : ''}</div>
      <div class="tname">${esc(t.name)}</div>
      <ul>${scorers(t.scorers || [])}</ul>
    </div>`;
  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
${FONT_CSS}
:root{--navy:#070b1f;--gold:#e3b54a;--gold2:#fff1c4;--white:#f7f8fc}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:'CardFont','DejaVu Sans',sans-serif;font-synthesis:none;color:var(--white);background:var(--navy);position:relative}
.deco{position:absolute;inset:0;overflow:hidden;
  background:
    radial-gradient(800px 520px at 105% -10%, rgba(106,53,181,.55), transparent 60%),
    radial-gradient(640px 460px at -10% 110%, rgba(227,181,74,.22), transparent 60%),
    repeating-linear-gradient(-55deg, rgba(255,255,255,.025) 0 2px, transparent 2px 26px),
    linear-gradient(180deg,#0a1030,#060918)}
.slash{position:absolute;top:-40px;left:-60px;width:320px;height:1200px;background:linear-gradient(180deg,rgba(227,181,74,.16),rgba(227,181,74,0));transform:skewX(-14deg)}
.wrap{position:relative;padding:48px 60px;height:100%;display:flex;flex-direction:column}
.top{display:flex;justify-content:space-between;align-items:center}
.comp{border:2px solid var(--gold);color:var(--gold2);border-radius:999px;padding:6px 24px;font-size:24px;background:rgba(227,181,74,.08)}
.date{color:#c9cde0;font-size:22px}
h1{font-size:84px;line-height:1.05;margin-top:18px}
h1 em{font-style:normal;color:var(--gold)}
.board{margin-top:40px;display:grid;grid-template-columns:1fr auto 1fr;align-items:start;gap:20px}
.side{display:flex;flex-direction:column;align-items:center;text-align:center}
.big-crest{width:200px;height:200px;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:0 14px 34px rgba(0,0,0,.5),0 0 0 5px rgba(227,181,74,.6)}
.big-crest img{width:70%;height:70%;object-fit:contain}
.tname{margin-top:20px;font-size:40px}
.score{display:flex;align-items:center;gap:22px;margin-top:40px;direction:rtl}
.score b{font-size:150px;line-height:1;color:var(--white);direction:ltr;unicode-bidi:isolate;text-shadow:0 10px 30px rgba(0,0,0,.5)}
.score span{font-size:80px;color:var(--gold)}
ul{list-style:none;margin-top:22px;display:flex;flex-direction:column;gap:8px;align-items:center}
li{font-size:24px;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);border-radius:10px;padding:2px 14px;display:flex;gap:8px;align-items:center}
li .ball{font-family:'DejaVu Sans',sans-serif;font-size:18px}
li i{font-style:normal;color:#c9cde0;font-size:20px}
li em{font-style:normal;color:var(--gold);direction:ltr;unicode-bidi:isolate}
.result{margin-top:auto;align-self:center;background:var(--gold);color:var(--navy);font-size:40px;padding:8px 44px;border-radius:16px}
.foot{display:flex;justify-content:space-between;margin-top:26px;font-size:22px;color:#aeb3cc}
</style></head><body>
<div class="deco"><div class="slash"></div></div>
<div class="wrap">
  <div class="top"><span class="comp">${esc(d.competitionAr || '')}</span><span class="date">${fmtDate(d.kickoff)}</span></div>
  <h1>النتيجة <em>النهائية</em></h1>
  <div class="board">
    ${side(d.home)}
    <div class="score"><b>${esc(d.home.score)}</b><span>-</span><b>${esc(d.away.score)}</b></div>
    ${side(d.away)}
  </div>
  <div class="result">${esc(d.result || '')}</div>
  <div class="foot"><span>${d.extra ? esc(d.extra) : ''}</span><span>${[config.handle, '#ريال_مدريد'].filter(Boolean).map((x) => `<bdi>${esc(x)}</bdi>`).join(' · ')}</span></div>
</div>
</body></html>`;
}

// غلاف سلسلة الموضوع (1200×675)
export function topicHtml({ title, subtitle, crest, tag = '🧵 سلسلة' }) {
  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
${FONT_CSS}
:root{--navy:#070b1f;--gold:#e3b54a;--gold2:#fff1c4;--white:#f7f8fc}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1200px;height:675px;overflow:hidden}
body{font-family:'CardFont','DejaVu Sans',sans-serif;font-synthesis:none;color:var(--white);background:var(--navy);position:relative}
.deco{position:absolute;inset:0;overflow:hidden;
  background:
    radial-gradient(760px 480px at 108% -20%, rgba(106,53,181,.6), transparent 60%),
    radial-gradient(620px 420px at -10% 120%, rgba(227,181,74,.25), transparent 60%),
    repeating-linear-gradient(-55deg, rgba(255,255,255,.03) 0 2px, transparent 2px 26px),
    linear-gradient(180deg,#0a1030,#060918)}
.slash{position:absolute;top:-60px;left:80px;width:260px;height:900px;background:linear-gradient(180deg,rgba(227,181,74,.18),rgba(227,181,74,0));transform:skewX(-14deg)}
.wrap{position:relative;height:100%;padding:64px 72px;display:flex;flex-direction:column;justify-content:center}
.tag{align-self:flex-start;border:2px solid var(--gold);color:var(--gold2);border-radius:999px;padding:6px 24px;font-size:26px;background:rgba(227,181,74,.08)}
h1{font-size:92px;line-height:1.12;margin-top:28px;max-width:860px}
h1 .g{color:var(--gold)}
p{margin-top:22px;font-size:34px;color:#c9cde0;max-width:820px}
.crest{position:absolute;left:84px;top:50%;transform:translateY(-50%);width:230px;height:230px;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:0 18px 40px rgba(0,0,0,.5),0 0 0 6px rgba(227,181,74,.6)}
.crest img{width:72%;height:72%;object-fit:contain}
.foot{position:absolute;bottom:36px;right:72px;left:72px;display:flex;justify-content:space-between;font-size:24px;color:#aeb3cc}
</style></head><body>
<div class="deco"><div class="slash"></div></div>
${crest ? `<div class="crest"><img src="${esc(crest)}" onerror="this.parentNode.remove()"></div>` : ''}
<div class="wrap">
  <span class="tag">${esc(tag)}</span>
  <h1>${goldLast(esc(title))}</h1>
  ${subtitle ? `<p>${esc(subtitle)}</p>` : ''}
</div>
<div class="foot"><span><bdi>${esc(config.handle || '')}</bdi></span><span>#ريال_مدريد</span></div>
</body></html>`;
}

// آخر كلمة في العنوان باللون الذهبي
function goldLast(t) {
  const i = t.lastIndexOf(' ');
  return i > 0 ? `${t.slice(0, i)} <span class="g">${t.slice(i + 1)}</span>` : `<span class="g">${t}</span>`;
}

// ===== أساس مشترك للبطاقات الجديدة =====
const base = (w, h, extra = '') => `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><style>
${FONT_CSS}
:root{--navy:#070b1f;--gold:#e3b54a;--gold2:#fff1c4;--violet:#6a35b5;--white:#f7f8fc;--muted:#aeb3cc}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:${w}px;height:${h}px;overflow:hidden}
body{font-family:'CardFont','DejaVu Sans',sans-serif;font-synthesis:none;color:var(--white);background:var(--navy);position:relative}
.deco{position:absolute;inset:0;overflow:hidden;background:
  radial-gradient(${w * 0.75}px ${h * 0.45}px at 105% -10%, rgba(106,53,181,.55), transparent 60%),
  radial-gradient(${w * 0.6}px ${h * 0.35}px at -10% 110%, rgba(227,181,74,.22), transparent 60%),
  repeating-linear-gradient(-55deg, rgba(255,255,255,.025) 0 2px, transparent 2px 26px),
  linear-gradient(180deg,#0a1030,#060918)}
.slash{position:absolute;top:-40px;left:-60px;width:300px;height:${h + 200}px;background:linear-gradient(180deg,rgba(227,181,74,.16),rgba(227,181,74,0));transform:skewX(-14deg)}
.wrap{position:relative;height:100%;padding:48px 60px;display:flex;flex-direction:column}
.top{display:flex;justify-content:space-between;align-items:center}
.pill{border:2px solid var(--gold);color:var(--gold2);border-radius:999px;padding:6px 24px;font-size:24px;background:rgba(227,181,74,.08)}
.date{color:#c9cde0;font-size:22px}
h1{font-size:80px;line-height:1.08;margin-top:18px}
h1 em{font-style:normal;color:var(--gold)}
.mini-crest{width:64px;height:64px;border-radius:50%;background:#fff;display:grid;place-items:center;flex:none;box-shadow:0 0 0 3px rgba(227,181,74,.6)}
.mini-crest img{width:70%;height:70%;object-fit:contain}
.foot{display:flex;justify-content:space-between;margin-top:auto;padding-top:20px;font-size:22px;color:var(--muted)}
.n{direction:ltr;unicode-bidi:isolate}
${extra}
</style></head><body><div class="deco"><div class="slash"></div></div>`;
const handleTag = () => [config.handle, '#ريال_مدريد'].filter(Boolean).map((x) => `<bdi>${esc(x)}</bdi>`).join(' · ');
const miniCrest = (src) => (src ? `<div class="mini-crest"><img src="${esc(src)}" onerror="this.remove()"></div>` : '');

// 📊 إحصائيات المباراة (1080×1350)
// d: { competitionAr, kickoff, home:{name,crest,score}, away:{...}, rows:[{label, h, a, pct?}] }
export function statsHtml(d) {
  const rows = d.rows.map((r) => {
    const hv = parseFloat(r.h) || 0, av = parseFloat(r.a) || 0, tot = hv + av || 1;
    const hp = Math.round((hv / tot) * 100);
    return `<div class="row">
      <div class="vals"><b class="n">${esc(r.h)}${r.pct ? '%' : ''}</b><span>${esc(r.label)}</span><b class="n">${esc(r.a)}${r.pct ? '%' : ''}</b></div>
      <div class="bar"><i class="hb" style="width:${hp}%"></i><i class="ab" style="width:${100 - hp}%"></i></div>
    </div>`;
  }).join('');
  return base(1080, 1350, `
.score{display:flex;align-items:center;justify-content:center;gap:26px;margin-top:30px}
.team{display:flex;align-items:center;gap:14px;font-size:34px}
.sc{font-size:84px;color:var(--white);display:flex;align-items:center}
.sc span{color:var(--gold);margin:0 10px}
.rows{margin-top:40px;display:flex;flex-direction:column;gap:22px}
.vals{display:flex;justify-content:space-between;align-items:center;font-size:30px}
.vals span{color:#c9cde0;font-size:28px}
.vals b{font-size:36px;min-width:110px}
.vals b:last-child{text-align:left}
.bar{display:flex;gap:6px;height:14px;margin-top:8px}
.bar i{display:block;height:100%;border-radius:8px}
.hb{background:var(--gold)}
.ab{background:rgba(255,255,255,.35)}
.legend{display:flex;justify-content:space-between;margin-top:30px;font-size:24px;color:var(--muted)}
.legend .h{color:var(--gold)}`) + `
<div class="wrap">
  <div class="top"><span class="pill">${esc(d.competitionAr || '')}</span><span class="date">${fmtDate(d.kickoff)}</span></div>
  <h1>المباراة <em>بالأرقام</em></h1>
  <div class="score">
    <div class="team">${miniCrest(d.home.crest)}<span>${esc(d.home.name)}</span></div>
    <div class="sc"><b class="n">${esc(d.home.score)}</b><span>-</span><b class="n">${esc(d.away.score)}</b></div>
    <div class="team"><span>${esc(d.away.name)}</span>${miniCrest(d.away.crest)}</div>
  </div>
  <div class="rows">${rows}</div>
  <div class="legend"><span class="h">■ ${esc(d.home.name)}</span><span>■ ${esc(d.away.name)}</span></div>
  <div class="foot"><span>المصدر: ESPN</span><span>${handleTag()}</span></div>
</div></body></html>`;
}

// ⭐ أفضل لاعب في المباراة (1080×1350)
// d: { player, teamName, crest, matchLine, competitionAr, kickoff, stats:[{label,value}], source }
export function motmHtml(d) {
  const chips = (d.stats || []).slice(0, 6).map((s) => `<div class="chip"><b class="n">${esc(s.value)}</b><span>${esc(s.label)}</span></div>`).join('');
  return base(1080, 1350, `
.body{margin:auto 0}
.star{margin:0 auto;width:300px;height:300px;border-radius:50%;display:grid;place-items:center;position:relative;
  background:radial-gradient(circle at 50% 40%,rgba(227,181,74,.45),rgba(227,181,74,.05) 70%);box-shadow:0 0 0 4px rgba(227,181,74,.7),0 30px 80px rgba(227,181,74,.25)}
.star .big{width:230px;height:230px;border-radius:50%;background:#fff;display:grid;place-items:center}
.star .big img{width:72%;height:72%;object-fit:contain}
.star .trophy{position:absolute;bottom:-26px;background:var(--gold);color:var(--navy);font-size:30px;padding:4px 26px;border-radius:999px}
.name{margin-top:64px;text-align:center;font-size:110px;line-height:1.05;color:var(--gold)}
.team{text-align:center;font-size:34px;color:#c9cde0;margin-top:10px}
.match{text-align:center;font-size:32px;margin-top:18px}
.chips{display:flex;flex-wrap:wrap;justify-content:center;gap:16px;margin-top:48px}
.chip{min-width:200px;background:rgba(255,255,255,.07);border:1px solid rgba(227,181,74,.4);border-radius:18px;padding:14px 20px;text-align:center}
.chip b{display:block;font-size:52px;color:var(--white)}
.chip span{font-size:24px;color:#c9cde0}`) + `
<div class="wrap">
  <div class="top"><span class="pill">${esc(d.competitionAr || '')}</span><span class="date">${fmtDate(d.kickoff)}</span></div>
  <h1>أفضل لاعب <em>في المباراة</em></h1>
  <div class="body">
  <div class="star"><div class="big">${d.crest ? `<img src="${esc(d.crest)}" onerror="this.remove()">` : ''}</div><span class="trophy">⭐ MVP</span></div>
  <div class="name">${esc(d.player)}</div>
  <div class="team">${esc(d.teamName || '')}</div>
  <div class="match">${esc(d.matchLine || '')}</div>
  <div class="chips">${chips}</div>
  </div>
  <div class="foot"><span>${d.source ? `الاختيار: ${esc(d.source)}` : ''}</span><span>${handleTag()}</span></div>
</div></body></html>`;
}

// 🗞️ ترجمة غلاف صحيفة (1080×1350)
// d: { paper, date, main, sub, others:[...] }
export function coverHtml(d) {
  const others = (d.others || []).slice(0, 5).map((o) => `<li>${escN(o)}</li>`).join('');
  return base(1080, 1350, `
.paper{display:flex;align-items:center;gap:18px;margin-top:22px}
.paper b{font-size:44px;background:var(--white);color:#b00d1c;padding:2px 24px;border-radius:12px}
.paper span{font-size:30px;color:#c9cde0}
.body{margin:auto 0}
.main{font-size:104px;line-height:1.12;color:var(--gold)}
.sub{margin-top:28px;font-size:44px;line-height:1.45;color:var(--white)}
hr{border:0;height:2px;background:linear-gradient(90deg,transparent,rgba(227,181,74,.6),transparent);margin:44px 0 30px}
ul{list-style:none;display:flex;flex-direction:column;gap:18px}
li{font-size:36px;line-height:1.4;padding-right:30px;position:relative;color:#e4e6f0}
li::before{content:'';position:absolute;right:0;top:22px;width:12px;height:12px;border-radius:50%;background:var(--gold)}`) + `
<div class="wrap">
  <div class="top"><span class="pill">🗞️ ترجمة الغلاف</span><span class="date">${esc(d.date || '')}</span></div>
  <div class="paper"><b>${esc(d.paperLatin || '')}</b><span>صحيفة ${esc(d.paper)} الإسبانية</span></div>
  <div class="body">
  <div class="main">${escN(d.main || '')}</div>
  ${d.sub ? `<div class="sub">${escN(d.sub)}</div>` : ''}
  ${others ? `<hr><ul>${others}</ul>` : ''}
  </div>
  <div class="foot"><span>ترجمة: <bdi>${esc(config.handle || '')}</bdi></span><span>#ريال_مدريد</span></div>
</div></body></html>`;
}

// 📅 في مثل هذا اليوم (1080×1080)
// d: { dateAr, year, title, text, crest }
export function onThisDayHtml(d) {
  return base(1080, 1080, `
.body{margin:auto 0}
.year{font-size:230px;line-height:.9;color:var(--gold);text-align:right;text-shadow:0 14px 40px rgba(227,181,74,.25)}
.ago{font-size:30px;color:#c9cde0;margin-top:14px}
.title{font-size:64px;line-height:1.15;margin-top:34px}
.text{font-size:34px;line-height:1.5;color:#dfe2ee;margin-top:20px;max-width:900px}
.crest-bg{position:absolute;left:60px;bottom:120px;width:200px;height:200px;border-radius:50%;background:#fff;display:grid;place-items:center;opacity:.95;box-shadow:0 0 0 5px rgba(227,181,74,.6)}
.crest-bg img{width:72%;height:72%;object-fit:contain}`) + `
${d.crest ? `<div class="crest-bg"><img src="${esc(d.crest)}" onerror="this.parentNode.remove()"></div>` : ''}
<div class="wrap">
  <div class="top"><span class="pill">📅 في مثل هذا اليوم</span><span class="date">${esc(d.dateAr)}</span></div>
  <div class="body">
    <div class="year"><span class="n">${esc(d.year)}</span></div>
    ${d.ago ? `<div class="ago">قبل ${esc(d.ago)} سنة</div>` : ''}
    <div class="title">${escN(d.title)}</div>
    ${d.text ? `<div class="text">${escN(d.text)}</div>` : ''}
  </div>
  <div class="foot"><span></span><span>${handleTag()}</span></div>
</div></body></html>`;
}

// 🏆 جدول الترتيب (1080×1350)
// d: { competitionAr, matchday, rows:[{pos, name, crest, played, won, draw, lost, gd, pts, rm}] }
export function standingsHtml(d) {
  const rows = d.rows.map((r) => `<tr class="${r.rm ? 'rm' : ''}${r.gap ? ' gap' : ''}">
    <td class="pos n">${esc(r.pos)}</td>
    <td class="team">${r.crest ? `<img src="${esc(r.crest)}" onerror="this.remove()">` : '<i></i>'}<span>${esc(r.name)}</span></td>
    <td class="n">${esc(r.played)}</td><td class="n">${esc(r.won)}</td><td class="n">${esc(r.draw)}</td><td class="n">${esc(r.lost)}</td>
    <td class="n">${r.gd > 0 ? '+' : ''}${esc(r.gd)}</td><td class="pts n">${esc(r.pts)}</td></tr>`).join('');
  return base(1080, 1350, `
table{width:100%;border-collapse:separate;border-spacing:0 10px;margin-top:34px;font-size:34px}
th{font-size:22px;color:var(--muted);font-weight:normal;padding:0 8px;text-align:center}
th:nth-child(2){text-align:right}
td{background:rgba(255,255,255,.05);padding:17px 8px;text-align:center}
td:first-child{border-radius:0 14px 14px 0}
td:last-child{border-radius:14px 0 0 14px}
.pos{width:60px;color:#c9cde0}
.team{text-align:right;display:flex;align-items:center;gap:14px}
.team img,.team i{width:46px;height:46px;object-fit:contain;background:#fff;border-radius:50%;padding:4px;display:inline-block}
.pts{font-size:38px;color:var(--white)}
tr.rm td{background:linear-gradient(90deg,rgba(227,181,74,.15),rgba(227,181,74,.35));color:var(--white)}
tr.rm .pts,tr.rm .pos{color:var(--gold)}
tr.gap td{border-top:0}
.dots{text-align:center;color:var(--muted);font-size:28px;letter-spacing:6px}`) + `
<div class="wrap">
  <div class="top"><span class="pill">${esc(d.competitionAr || 'الدوري الإسباني')}</span><span class="date">${d.matchday ? `بعد الجولة ${esc(d.matchday)}` : ''}</span></div>
  <h1>جدول <em>الترتيب</em></h1>
  <table>
    <tr><th>#</th><th>الفريق</th><th>لعب</th><th>ف</th><th>ت</th><th>خ</th><th>الفارق</th><th>نقاط</th></tr>
    ${rows}
  </table>
  <div class="foot"><span>المصدر: football-data.org</span><span>${handleTag()}</span></div>
</div></body></html>`;
}

// 🩺 الغيابات (1080×1350)
// d: { matchLine, competitionAr, kickoff, players:[{name, reason, type:'injury'|'suspension'|'other', ret}] }
export function absencesHtml(d) {
  const icon = { injury: '🩹', suspension: '🟥', illness: '🤒', other: '❔' };
  const list = d.players.map((p) => `<div class="p">
    <span class="ic">${icon[p.type] || icon.other}</span>
    <div class="info"><b>${esc(p.name)}</b><span>${esc(p.reason || '')}</span></div>
    ${p.ret ? `<em>${esc(p.ret)}</em>` : ''}
  </div>`).join('');
  return base(1080, 1350, `
.match{font-size:34px;color:#c9cde0;margin-top:10px}
.list{margin:auto 0;display:flex;flex-direction:column;gap:16px}
.p{display:flex;align-items:center;gap:22px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);border-radius:20px;padding:18px 26px}
.ic{font-family:'DejaVu Sans',sans-serif;font-size:40px;width:56px;text-align:center}
.info{display:flex;flex-direction:column}
.info b{font-size:44px}
.info span{font-size:26px;color:#c9cde0}
.p em{margin-right:auto;font-style:normal;font-size:24px;color:var(--gold);border:1px solid rgba(227,181,74,.5);border-radius:999px;padding:4px 16px}`) + `
<div class="wrap">
  <div class="top"><span class="pill">${esc(d.competitionAr || '')}</span><span class="date">${fmtDate(d.kickoff)}</span></div>
  <h1>غيابات <em>ريال مدريد</em></h1>
  <div class="match">${esc(d.matchLine || '')}</div>
  <div class="list">${list}</div>
  <div class="foot"><span>🩹 إصابة · 🟥 إيقاف · 🤒 مرض</span><span>${handleTag()}</span></div>
</div></body></html>`;
}
