// أخبار عامة: يجمع ← يختار الأهم ← يترجم ويختصر ← ينشر
import crypto from 'node:crypto';
import Parser from 'rss-parser';
import { config } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { postText } from './x.js';
import { fetchOfficialItems } from './official.js';
import { fetchXItems } from './xsources.js';

const norm = (s) => (s || '').toLowerCase().replace(/[^\p{L}\p{N} ]/gu, '').replace(/\s+/g, ' ').trim();
const keyOf = (item) => crypto.createHash('sha1').update(norm(item.title)).digest('hex').slice(0, 16);

async function fetchFeeds() {
  const parser = new Parser({ timeout: 15000, headers: { 'User-Agent': 'Mozilla/5.0 RM-News-Bot' } });
  const cutoff = Date.now() - (config.maxAgeHours || 6) * 3600 * 1000;
  const kw = config.keywords.map((k) => k.toLowerCase());
  const results = await Promise.allSettled(config.feeds.map(async (feed) => {
    const parsed = await parser.parseURL(feed.url);
    return parsed.items.map((it) => ({
      source: feed.name,
      title: (it.title || '').trim(),
      link: it.link,
      date: new Date(it.isoDate || it.pubDate || Date.now()).getTime(),
      snippet: (it.contentSnippet || it.content || '').replace(/\s+/g, ' ').slice(0, 400),
      filtered: feed.filtered,
    }));
  }));
  const items = [];
  results.forEach((r, i) => {
    if (r.status === 'fulfilled') items.push(...r.value);
    else console.warn(`⚠️ فشل المصدر ${config.feeds[i].name}: ${r.reason?.message}`);
  });
  return items.filter((it) => {
    if (!it.title || it.date < cutoff) return false;
    if (it.filtered) return true;
    const text = `${it.title} ${it.snippet}`.toLowerCase();
    return kw.some((k) => text.includes(k));
  });
}

async function writeTweets(candidates, recentTweets, max) {
  const list = candidates.map((c, i) => `[${i}] ${c.official ? '[رسمي] ' : ''}(${c.source}) ${c.title}${c.snippet && c.snippet !== c.title ? `\n${c.snippet}` : ''}`).join('\n\n');
  const prompt = `أنت محرر حساب عربي لأخبار ريال مدريد على منصة X.

هذه أخبار جديدة من مصادر مختلفة: مواقع إخبارية، والموقع الرسمي لريال مدريد، وتغريدات من حسابات على X (بعضها بالإنجليزي أو الإسباني، وبعضها مكرر بصياغات مختلفة). المصادر المعلّمة بـ [رسمي] تابعة للنادي نفسه:

${list}

وهذه آخر تغريدات نشرناها (لا تكرر نفس الخبر):
${recentTweets.map((t) => '- ' + t).join('\n') || '- لا يوجد'}

المطلوب:
1. ادمج الأخبار المكررة واعتبرها خبراً واحداً.
2. اختر أهم ${max} خبر كحد أقصى، فقط إذا كان خبراً حقيقياً ومهماً (نتائج، إصابات، انتقالات مؤكدة أو من مصادر موثوقة، تصريحات مهمة). تجاهل المقالات التحليلية العامة والإشاعات الضعيفة والأخبار التي سبق نشرها. إذا لا يوجد شيء يستحق، أرجع قائمة فارغة.
3. تجاهل أخبار التشكيلة الرسمية وتصريحات المؤتمرات الصحفية للمدربين، لأننا ننشرها بشكل منفصل.
4. اكتب لكل خبر تغريدة بالعربية الفصحى المبسطة، مختصرة وواضحة، لا تتجاوز 260 حرفاً، وتنتهي بذكر المصدر بصيغة: "المصدر: اسم المصدر". ${config.style || ''}
5. لا تخترع أي معلومة غير موجودة في النص. إذا كان الخبر إشاعة، وضّح ذلك (مثل: "تقارير:").
6. أخبار المصادر [رسمي] لها الأولوية (بيانات النادي، الإصابات، قائمة المباراة، التعاقدات). ابدأها بـ "رسمياً:" فقط إذا كانت إعلاناً رسمياً فعلاً، واكتب المصدر: "المصدر: الموقع الرسمي لريال مدريد" أو "المصدر: الحساب الرسمي لريال مدريد".
7. لتغريدات الصحفيين اكتب اسم الصحفي بالعربي في المصدر (مثل: "المصدر: فابريزيو رومانو"). تجاهل التغريدات الدعائية، والفيديوهات بدون معلومة، وآراء المشجعين، والتغريدات اللي ما فيها خبر جديد.

أرجع JSON فقط بهذا الشكل بدون أي نص آخر:
{"tweets":[{"text":"...","items":[0,3]}]}`;
  const json = parseJson(await askClaude(prompt, { maxTokens: 1500 }));
  return (json.tweets || []).filter((t) => fitsTweet(t.text)).slice(0, max);
}

export async function runNews(state) {
  const every = (config.newsEveryMinutes || 30) * 60000;
  if (state.lastNewsRun && Date.now() - state.lastNewsRun < every - 90000) return;
  state.lastNewsRun = Date.now();

  const seen = new Set(state.seen);
  const [rss, official, xs] = await Promise.all([
    fetchFeeds(),
    fetchOfficialItems(state).catch((e) => { console.warn('⚠️ الموقع الرسمي:', e.message); return []; }),
    fetchXItems(state).catch((e) => { console.warn('⚠️ X:', e.message); return []; }),
  ]);
  const all = [...official, ...xs, ...rss];
  const fresh = [];
  const keys = new Set();
  for (const it of [...official, ...xs, ...rss.sort((a, b) => b.date - a.date)]) {
    const k = keyOf(it);
    if (seen.has(k) || seen.has(it.link) || keys.has(k)) continue;
    keys.add(k);
    fresh.push(it);
  }
  console.log(`📰 أخبار: ${all.length} مطابق، منها ${fresh.length} جديد`);
  if (!fresh.length) return;

  const candidates = fresh.slice(0, 40);
  const tweets = await writeTweets(candidates, state.tweets, Number(config.maxTweetsPerRun || 2));
  console.log(`✍️ تم اختيار ${tweets.length} تغريدة`);

  for (const t of tweets) {
    let text = t.text.trim();
    if (config.includeLink) {
      const url = candidates[t.items?.[0]]?.link;
      if (url && [...text].length + 24 <= 280) text += `\n${url}`;
    }
    try {
      await postText(text);
      state.tweets.push(t.text);
    } catch (e) {
      console.error('❌ فشل النشر:', e.data ? JSON.stringify(e.data) : e.message);
    }
  }
  for (const c of candidates) state.seen.push(keyOf(c), c.link);
}
