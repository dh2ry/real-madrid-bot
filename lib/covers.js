// 🗞️ ترجمة غلاف صحيفتي ماركا وآس كل يوم (بطاقة مصممة فيها العناوين بالعربي)
import { config } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { coverHtml, renderPng } from './card.js';
import { postImage } from './x.js';

const opt = (k, d) => config.covers?.[k] ?? d;
const PAPERS = [
  { id: 'marca', name: 'ماركا', latin: 'MARCA' },
  { id: 'as', name: 'آس', latin: 'AS' },
];

// تاريخ اليوم بتوقيت مدريد
function madridDate() {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit', day: '2-digit' })
    .formatToParts(new Date()).map((x) => [x.type, x.value]));
  return { y: p.year, m: p.month, d: p.day };
}
const localHour = () => Number(new Intl.DateTimeFormat('en-GB', { timeZone: config.timezone || 'Asia/Riyadh', hour: '2-digit', hourCycle: 'h23' }).format(new Date()));

async function getCover(paper, { y, m, d }) {
  const urls = (opt('urls', null)?.[paper.id] || ['https://img.kiosko.net/{y}/{m}/{d}/es/{id}.750.jpg'])
    .map((u) => u.replace('{y}', y).replace('{m}', m).replace('{d}', d).replace('{id}', paper.id));
  for (const url of urls) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
      if (!res.ok) continue;
      const type = res.headers.get('content-type') || 'image/jpeg';
      if (!type.startsWith('image/')) continue;
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length < 20000) continue; // صورة فاضية أو بديلة
      return { media_type: type.split(';')[0], data: buf.toString('base64') };
    } catch { /* جرّب الرابط اللي بعده */ }
  }
  return null;
}

export async function runCovers(state) {
  if (config.covers?.enabled === false) return;
  if (localHour() < opt('fromHour', 6)) return;
  const date = madridDate();
  const dayKey = `${date.y}-${date.m}-${date.d}`;
  const retry = opt('retryMinutes', 30) * 60000;
  const enabled = opt('papers', ['marca', 'as']);

  for (const paper of PAPERS.filter((p) => enabled.includes(p.id))) {
    const key = `cover:${paper.id}:${dayKey}`;
    if (state.done[key]) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < retry) continue;
    state.attempts[key] = Date.now();

    const img = await getCover(paper, date);
    if (!img) { console.log(`⏳ غلاف ${paper.name}: لسه ما نزل`); continue; }

    let j;
    try {
      j = parseJson(await askClaude(`هذه صورة غلاف صحيفة ${paper.latin} الإسبانية لليوم.
اقرأ الغلاف وترجم عناوينه إلى العربية الفصحى المبسطة بدقة، بدون إضافة معلومات غير موجودة.

- main: العنوان الرئيسي الأكبر (مترجم، قصير وقوي).
- sub: العنوان الفرعي أو الجملة التوضيحية تحت العنوان الرئيسي (إن وجد).
- others: حتى 4 عناوين أخرى بارزة في الغلاف، الأهم أولاً، وخصوصاً ما يتعلق بريال مدريد.
- rm: true إذا كان العنوان الرئيسي عن ريال مدريد.
- tweet: نص تغريدة قصير (حتى 200 حرف) يبدأ بـ "🗞️ غلاف صحيفة ${paper.name} اليوم:" ثم العنوان الرئيسي.

إذا كانت الصورة غير واضحة أو ليست غلاف صحيفة، أرجع {"ok": false}.
أرجع JSON فقط: {"ok":true,"main":"","sub":"","others":[],"rm":true,"tweet":""}`, { images: [img], maxTokens: 1500 }));
    } catch (e) { console.warn(`⚠️ قراءة غلاف ${paper.name}:`, e.message); continue; }
    if (!j.ok || !j.main) { console.warn(`⚠️ غلاف ${paper.name}: ما قدر يقرأه`); continue; }
    if (opt('onlyRealMadrid', false) && !j.rm) { console.log(`⏭️ غلاف ${paper.name}: العنوان الرئيسي مو عن ريال`); state.done[key] = Date.now(); continue; }

    try {
      const dateAr = new Intl.DateTimeFormat('ar-u-nu-latn', { timeZone: 'Europe/Madrid', weekday: 'long', day: 'numeric', month: 'long' }).format(new Date());
      const png = await renderPng(coverHtml({ paper: paper.name, paperLatin: paper.latin, date: dateAr, main: j.main, sub: j.sub, others: j.others }), { width: 1080, height: 1350 });
      let text = `${(j.tweet || `🗞️ غلاف صحيفة ${paper.name} اليوم:\n\n${j.main}`).trim()}\n\n#ريال_مدريد`;
      if (!fitsTweet(text)) text = `🗞️ غلاف صحيفة ${paper.name} اليوم\n\n#ريال_مدريد`;
      await postImage(text, png, `ترجمة غلاف صحيفة ${paper.name}: ${j.main}`, `cover-${paper.id}.png`);
      state.done[key] = Date.now();
    } catch (e) { console.error(`❌ غلاف ${paper.name}:`, e.data ? JSON.stringify(e.data) : e.message); }
  }
}
