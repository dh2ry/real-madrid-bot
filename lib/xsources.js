// أخبار من حسابات X (تويتر): الحساب الرسمي والصحفيين
// X يحاسب على كل تغريدة يقرأها البوت، فنبحث فقط عن التغريدات الجديدة اللي تخص ريال مدريد
import { config } from './config.js';
import { xClient } from './x.js';

const opt = (k, d) => config.xSources?.[k] ?? d;
const KEYWORDS = '("Real Madrid" OR "ريال مدريد" OR RealMadrid OR #HalaMadrid)';

function queries() {
  const q = [];
  const from = (list) => `(${list.map((u) => `from:${u.replace(/^@/, '')}`).join(' OR ')})`;
  const chunks = (list, n) => Array.from({ length: Math.ceil(list.length / n) }, (_, i) => list.slice(i * n, i * n + n));
  // حسابات خاصة بريال مدريد: كل تغريداتهم
  for (const c of chunks(opt('rmAccounts', []), 8)) q.push(`${from(c)} -is:retweet -is:reply`);
  // حسابات عامة: بس التغريدات اللي فيها ريال مدريد
  for (const c of chunks(opt('generalAccounts', []), 6)) q.push(`${from(c)} ${KEYWORDS} -is:retweet -is:reply`);
  return q;
}

export async function fetchXItems(state) {
  if (config.xSources?.enabled === false) return [];
  const qs = queries();
  if (!qs.length) return [];
  state.xSince ??= {};
  const official = new Set(opt('officialAccounts', ['realmadrid']).map((u) => u.toLowerCase()));
  const items = [];
  for (const query of qs) {
    const params = {
      query,
      max_results: opt('maxPerQuery', 25),
      'tweet.fields': 'created_at,note_tweet',
      expansions: 'author_id',
      'user.fields': 'username,name',
    };
    if (state.xSince[query]) params.since_id = state.xSince[query];
    else params.start_time = new Date(Date.now() - 2 * 3600000).toISOString(); // أول مرة: آخر ساعتين فقط
    try {
      const res = await xClient().v2.get('tweets/search/recent', params);
      const users = new Map((res.includes?.users || []).map((u) => [u.id, u]));
      if (res.meta?.newest_id) state.xSince[query] = res.meta.newest_id;
      for (const t of res.data || []) {
        const u = users.get(t.author_id) || {};
        const text = (t.note_tweet?.text || t.text).replace(/https:\/\/t\.co\/\S+/g, '').trim();
        if (text.length < 25) continue; // تغريدات فيديو/صورة بدون نص
        items.push({
          source: `${u.name || u.username} (@${u.username}) على X`,
          official: official.has((u.username || '').toLowerCase()),
          title: text.slice(0, 200),
          snippet: text.slice(0, 600),
          link: `https://x.com/${u.username}/status/${t.id}`,
          date: Date.parse(t.created_at) || Date.now(),
          filtered: true,
        });
      }
    } catch (e) {
      console.warn('⚠️ بحث X:', e.data ? JSON.stringify(e.data).slice(0, 300) : e.message);
    }
  }
  console.log(`🐦 X: ${items.length} تغريدة جديدة من الحسابات`);
  return items;
}
