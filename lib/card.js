// تصميم بطاقة التشكيلة (HTML) وتحويلها لصورة PNG باستخدام Chrome
import fs from 'node:fs';
import { chromium } from 'playwright-core';
import { config, env, fmtTime, fmtDate, ROOT } from './config.js';

// الخط مضمّن داخل الصورة مباشرة (ما يحتاج إنترنت)
const FONT_FILE = new URL(config.fontFile || 'assets/fonts/thmanyah-serif-display-bold.otf', ROOT);
const FONT_CSS = fs.existsSync(FONT_FILE)
  ? `@font-face{font-family:'CardFont';src:url(data:font/otf;base64,${fs.readFileSync(FONT_FILE).toString('base64')}) format('opentype');font-weight:100 900;font-display:block}`
  : '';

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
  const browser = await chromium.launch(opts);
  try {
    const page = await browser.newPage({ viewport: { width, height } });
    await page.setContent(html, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
    await page.evaluate(() => document.fonts.ready);
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
