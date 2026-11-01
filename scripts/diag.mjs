// فحص سريع للمفاتيح والخدمات — يكتب النتيجة كملاحظات في صفحة التشغيل (بدون أي مفاتيح)
import { TwitterApi } from 'twitter-api-v2';
const env = process.env;
const note = (ok, name, msg) => console.log(`::${ok ? 'notice' : 'error'} title=${name}::${String(msg).replace(/\s+/g, ' ').slice(0, 400)}`);
const t = (ms) => AbortSignal.timeout(ms);

try {
  const r = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST', signal: t(60000),
    headers: { 'x-api-key': env.ANTHROPIC_API_KEY || '', 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'claude-sonnet-5-5', max_tokens: 5, messages: [{ role: 'user', content: 'hi' }] }) });
  const b = await r.text();
  note(r.ok, 'Claude', r.ok ? 'OK' : `${r.status} ${b}`);
} catch (e) { note(false, 'Claude', e.message); }

try {
  const c = new TwitterApi({ appKey: env.X_API_KEY, appSecret: env.X_API_SECRET, accessToken: env.X_ACCESS_TOKEN, accessSecret: env.X_ACCESS_SECRET });
  const me = await c.v2.me({ 'user.fields': ['protected', 'withheld', 'public_metrics', 'verified_type'] });
  note(true, 'X read', `OK @${me.data.username} ${JSON.stringify({ protected: me.data.protected, withheld: me.data.withheld, metrics: me.data.public_metrics, verified: me.data.verified_type })}`);
  if (env.DIAG_TIMELINE) {
    const tl = await c.v2.userTimeline(me.data.id, { max_results: 40, 'tweet.fields': ['created_at'], exclude: ['replies'] });
    for (const tw of tl.data?.data || []) console.log(`::notice title=${tw.created_at}::${tw.text.replace(/\s+/g, ' ').slice(0, 120)}`);
  }
} catch (e) { note(false, 'X read', `${e.code || ''} ${JSON.stringify(e.data || e.message)}`); }

try {
  const r = await fetch('https://api.football-data.org/v4/teams/86', { headers: { 'X-Auth-Token': env.FOOTBALL_DATA_KEY || '' }, signal: t(20000) });
  note(r.ok, 'football-data', r.ok ? 'OK' : `${r.status} ${(await r.text()).slice(0, 200)}`);
} catch (e) { note(false, 'football-data', e.message); }

try {
  const r = await fetch('https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard', { signal: t(20000) });
  note(r.ok, 'ESPN', r.ok ? 'OK' : r.status);
} catch (e) { note(false, 'ESPN', e.message); }
