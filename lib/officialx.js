// 🏛️ ترجمة كل تغريدات حساب ريال مدريد الرسمي
import { config, DRY_RUN } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { xClient, postText } from './x.js';

const opt = (k, d) => config.officialX?.[k] ?? d;

export const officialAccounts = () => (config.officialX?.enabled === false ? [] : opt('accounts', ['realmadrid']).map((a) => a.replace(/^@/, '').toLowerCase()));

export async function runOfficialX(state, { liveNow = false } = {}) {
  const accounts = officialAccounts();
  if (!accounts.length) return;
  const every = opt('everyMinutes', 10) * 60000;
  if (state.officialXRun && Date.now() - state.officialXRun < every - 60000) return;
  state.officialXRun = Date.now();

  const query = `(${accounts.map((a) => `from:${a}`).join(' OR ')}) -is:retweet -is:reply`;
  const params = { query, max_results: opt('maxPerRun', 20), 'tweet.fields': 'created_at,note_tweet,lang,referenced_tweets', expansions: 'author_id', 'user.fields': 'username' };
  if (state.officialSince) params.since_id = state.officialSince;
  else params.start_time = new Date(Date.now() - 60 * 60000).toISOString(); // أول مرة: آخر ساعة فقط

  let res;
  try { res = await xClient().v2.get('tweets/search/recent', params); } catch (e) {
    console.warn('⚠️ تغريدات الحساب الرسمي:', e.data ? JSON.stringify(e.data).slice(0, 300) : e.message); return;
  }
  if (res.meta?.newest_id) state.officialSince = res.meta.newest_id;
  const tweets = (res.data || [])
    .map((t) => ({ id: t.id, at: Date.parse(t.created_at) || 0, text: (t.note_tweet?.text || t.text).replace(/https:\/\/t\.co\/\S+/g, '').trim(), quote: t.referenced_tweets?.some((r) => r.type === 'quoted') }))
    .sort((a, b) => a.at - b.at);
  console.log(`🏛️ الحساب الرسمي: ${tweets.length} تغريدة جديدة`);
  if (!tweets.length) return;

  // وقت المباراة البوت ينشر الأحداث بنفسه، فنتجاهل تغريدات الحساب عن الأهداف والبطاقات لتفادي التكرار
  if (liveNow && opt('skipDuringLive', true)) { console.log('⏭️ تجاهل تغريدات الحساب الرسمي وقت المباراة'); return; }

  const minLen = opt('minLength', 12);
  const usable = tweets.filter((t) => t.text.replace(/[\p{Extended_Pictographic}\s#@]/gu, '').length >= minLen);
  if (!usable.length) return;

  const prompt = `ترجم تغريدات حساب ريال مدريد الرسمي التالية إلى العربية الفصحى المبسطة، بأسلوب حساب رياضي عربي.

قواعد:
- ترجمة أمينة للمعنى بدون إضافة أو حذف معلومات. حافظ على الإيموجي.
- أسماء اللاعبين والأماكن كما تكتبها الصحافة الرياضية العربية.
- الهاشتاقات الإسبانية والإنجليزية: احذفها، وأضف في النهاية #ريال_مدريد مرة وحدة.
- كل ترجمة لا تتجاوز 240 حرفاً.
- إذا كانت التغريدة دعاية تجارية أو بيع تذاكر أو منتجات، أو ما لها معنى بدون الفيديو/الصورة، أرجع "skip": true.

التغريدات:
${usable.map((t, i) => `[${i}] ${t.text}`).join('\n\n')}

أرجع JSON فقط: {"items":[{"i":0,"skip":false,"ar":"..."}]}`;

  let j;
  try { j = parseJson(await askClaude(prompt, { maxTokens: 3000 })); } catch (e) { console.warn('⚠️ ترجمة الحساب الرسمي:', e.message); return; }
  const prefix = opt('prefix', '🏛️ ريال مدريد:');
  for (const it of j.items || []) {
    const t = usable[it.i];
    if (!t || it.skip || !it.ar) continue;
    const text = `${prefix}\n\n${it.ar.trim()}`;
    if (!fitsTweet(text)) continue;
    try { await postText(text); } catch (e) { console.error('❌ نشر ترجمة رسمية:', e.data ? JSON.stringify(e.data) : e.message); }
  }
}
