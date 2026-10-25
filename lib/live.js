// أحداث المباراة المباشرة (أهداف، بطاقات، بداية، استراحة، نهاية) من بيانات ESPN
import { config, DRY_RUN } from './config.js';
import { askClaude, parseJson } from './claude.js';
import { postText } from './x.js';

const opt = (k, d) => config.live?.[k] ?? d;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const isRM = (name = '') => /real madrid/i.test(name) && !/castilla/i.test(name);
const ymd = (ts) => new Date(ts).toISOString().slice(0, 10).replace(/-/g, '');

const LEAGUES = ['esp.1', 'uefa.champions', 'esp.copa_del_rey', 'esp.super_cup', 'fifa.cwc', 'club.friendly'];
const LEAGUE_BY_COMP = { 'Primera Division': 'esp.1', 'UEFA Champions League': 'uefa.champions', 'Copa del Rey': 'esp.copa_del_rey' };

async function scoreboard(league, ts) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${league}/scoreboard?dates=${ymd(ts)}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(15000) });
  if (!res.ok) throw new Error(`ESPN ${league} ${res.status}`);
  return (await res.json()).events || [];
}

// يلقى المباراة في ESPN
async function findEvent(f) {
  const first = LEAGUE_BY_COMP[f.competition];
  const leagues = [first, ...LEAGUES.filter((l) => l !== first)].filter(Boolean);
  for (const league of leagues) {
    for (const ts of [f.kickoff, f.kickoff - 86400000]) {
      const evs = await scoreboard(league, ts).catch(() => []);
      const ev = evs.find((e) => Math.abs(Date.parse(e.date) - f.kickoff) < 3 * 3600000
        && e.competitions?.[0]?.competitors?.some((c) => isRM(c.team?.displayName) || isRM(c.team?.name)));
      if (ev) return { league, id: ev.id };
    }
  }
  return null;
}

async function fetchEvent(ref, f) {
  for (const ts of [f.kickoff, f.kickoff - 86400000]) {
    const ev = (await scoreboard(ref.league, ts)).find((e) => e.id === ref.id);
    if (ev) return ev;
  }
  throw new Error('ESPN: المباراة غير موجودة');
}

// صفحة تفاصيل المباراة: فيها الأحداث (أهداف وبطاقات) بشكل أكمل من صفحة النتائج
async function summaryEvents(ref) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${ref.league}/summary?event=${ref.id}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(15000) });
  if (!res.ok) throw new Error(`ESPN summary ${res.status}`);
  const j = await res.json();
  const out = [];
  for (const k of j.keyEvents || []) {
    const t = `${k.type?.text || ''} ${k.type?.type || ''}`.toLowerCase();
    const scoring = k.scoringPlay ?? (/goal|penalty - scored/.test(t) && !/disallow|miss|saved/.test(t));
    const yellow = /yellow/.test(t) && !/red/.test(t);
    const red = /red card|red-card|redcard|second yellow/.test(t);
    if (!scoring && !yellow && !red) continue;
    out.push({
      type: { id: k.type?.id, text: k.type?.text },
      clock: k.clock,
      team: k.team,
      scoringPlay: !!scoring && !red && !yellow,
      yellowCard: yellow,
      redCard: red,
      penaltyKick: /penalty/.test(t),
      ownGoal: /own goal/.test(t),
      shootout: !!k.shootout || /shootout/.test(t),
      athletesInvolved: (k.participants || []).map((p) => p.athlete).filter(Boolean),
    });
  }
  const clock = j.header?.competitions?.[0]?.status?.displayClock;
  return { events: out, clock };
}

function parse(ev) {
  const comp = ev.competitions[0];
  const st = comp.status?.type || ev.status?.type || {};
  const team = (side) => {
    const c = comp.competitors.find((x) => x.homeAway === side);
    return { id: String(c.team.id), name: c.team.displayName || c.team.name, score: Number(c.score) || 0, pens: c.shootoutScore };
  };
  return { state: st.state, name: st.name || '', detail: st.detail || st.shortDetail || '', completed: !!st.completed,
    home: team('home'), away: team('away'), details: comp.details || [] };
}

const keyOf = (d) => [d.type?.id || d.type?.text, d.clock?.value ?? d.clock?.displayValue, d.athletesInvolved?.[0]?.id || '', d.team?.id].join('|');
const minute = (d) => (d.clock?.displayValue || '').replace(/'/g, '').trim();

// يحسب النتيجة بعد كل هدف (مع معالجة الهدف العكسي)
function tallies(m) {
  const goals = m.details.filter((d) => d.scoringPlay && !d.shootout);
  const run = (flipOG) => {
    let h = 0, a = 0;
    const out = new Map();
    for (const d of goals) {
      let tid = String(d.team?.id);
      if (d.ownGoal && flipOG) tid = tid === m.home.id ? m.away.id : m.home.id;
      if (tid === m.home.id) h++; else a++;
      out.set(keyOf(d), { h, a, teamId: tid });
    }
    return { out, h, a };
  };
  const plain = run(false);
  if (plain.h === m.home.score && plain.a === m.away.score) return plain.out;
  const flipped = run(true);
  return flipped.h === m.home.score && flipped.a === m.away.score ? flipped.out : plain.out;
}

// ترجمة الأسماء للعربي مع حفظها
async function arabic(state, names) {
  state.names ??= { 'Real Madrid': 'ريال مدريد' };
  const missing = [...new Set(names.filter((n) => n && !state.names[n]))];
  if (missing.length) {
    try {
      const j = parseJson(await askClaude(`ترجم هذه الأسماء (لاعبين أو أندية كرة قدم) إلى العربية كما تكتبها وسائل الإعلام الرياضية العربية. للاعبين استخدم الاسم الشائع المختصر (كلمة أو كلمتين).
${JSON.stringify(missing)}
أرجع JSON فقط: {"English":"عربي"}`, { maxTokens: 800 }));
      Object.assign(state.names, j);
    } catch (e) { console.warn('⚠️ ترجمة الأسماء:', e.message); }
  }
  return (n) => state.names[n] || n;
}

export function shouldGoLive(f, state) {
  if (config.live?.enabled === false || state.live?.[f.id]?.finished) return false;
  const mins = (Date.now() - f.kickoff) / 60000;
  return mins >= -(opt('startMinutesBefore', 15)) && mins <= opt('maxMinutes', 200);
}

async function tick(state, f) {
  const L = (state.live[f.id] ??= { posted: [], phases: {}, lastScore: null });
  if (!L.espn) {
    L.espn = await findEvent(f);
    if (!L.espn) {
      if (Date.now() > f.kickoff + 30 * 60000) { console.warn('⚠️ ما لقيت المباراة في ESPN — إيقاف الوضع المباشر'); L.finished = true; return true; }
      console.log('⏳ المباراة لسه مو ظاهرة في ESPN');
      return false;
    }
    console.log(`📡 ESPN: ${L.espn.league} / ${L.espn.id}`);
  }

  const m = parse(await fetchEvent(L.espn, f));
  if (m.state === 'pre') return false;
  try {
    const sum = await summaryEvents(L.espn);
    if (sum.events.length >= m.details.length) m.details = sum.events;
    m.clock = sum.clock;
  } catch (e) { console.warn('⚠️ تفاصيل المباراة:', e.message); }
  console.log(`📊 ${m.home.name} ${m.home.score}-${m.away.score} ${m.away.name} | ${m.detail} | أحداث: ${m.details.length}`);
  const nowMin = parseInt(String(m.clock || m.detail).replace(/[^\d+]/g, '')) || 0;

  const tag = '\n\n#ريال_مدريد';
  const rmHome = isRM(m.home.name);
  const ar = await arabic(state, [m.home.name, m.away.name, ...m.details.map((d) => d.athletesInvolved?.[0]?.displayName)]);
  const H = ar(m.home.name), A = ar(m.away.name);
  const line = (h, a) => `${H} ${h} - ${a} ${A}`;
  const posts = [];

  if (!L.phases.kickoff && opt('kickoff', true)) {
    posts.push(`🏁 انطلقت المباراة\n\n${H} × ${A}${tag}`);
    L.phases.kickoff = true;
  }

  // ⚽ الأهداف و 🟨🟥 البطاقات
  const goalScores = tallies(m);
  for (const d of m.details) {
    const k = keyOf(d);
    if (L.posted.includes(k) || d.shootout) continue;
    const player = ar(d.athletesInvolved?.[0]?.displayName) || '';
    const teamName = String(d.team?.id) === m.home.id ? H : A;
    const min = minute(d) ? `\n⏱️ الدقيقة ${minute(d)}` : '';
    let text = null;

    if (d.scoringPlay) {
      const s = goalScores.get(k) || { h: m.home.score, a: m.away.score, teamId: String(d.team?.id) };
      const forRM = (s.teamId === m.home.id) === rmHome;
      const how = d.ownGoal ? ' (هدف عكسي)' : d.penaltyKick ? ' (ركلة جزاء)' : '';
      text = forRM
        ? `⚽️ قوووووول لريال مدريد!\n\n${d.ownGoal ? `هدف عكسي عن طريق ${player}` : player + how}${min}\n\n${line(s.h, s.a)}${tag}`
        : `⚽️ هدف لـ${s.teamId === m.home.id ? H : A}\n\n${d.ownGoal ? `هدف عكسي عن طريق ${player}` : player + how}${min}\n\n${line(s.h, s.a)}${tag}`;
      L.lastScore = [s.h, s.a];
    } else if (d.redCard && opt('redCards', true)) {
      text = `🟥 بطاقة حمراء!\n\n${player} (${teamName})${min}${tag}`;
    } else if (d.yellowCard && nowMin && parseInt(minute(d)) < nowMin - 15) {
      text = null; // بطاقة صفراء قديمة (البوت بدأ متأخر) — ما ننشرها
    } else if (d.yellowCard) {
      const rmCard = (String(d.team?.id) === m.home.id) === rmHome;
      if (rmCard ? opt('yellowCards', true) : opt('opponentYellowCards', true)) {
        text = `🟨 بطاقة صفراء\n\n${player} (${teamName})${min}${tag}`;
      }
    }
    if (text) posts.push(text);
    L.posted.push(k);
  }

  // ❌ هدف ملغي (VAR): النتيجة نزلت عن آخر نتيجة نشرناها
  if (L.lastScore && m.home.score + m.away.score < L.lastScore[0] + L.lastScore[1]) {
    posts.push(`❌ إلغاء الهدف بعد العودة لتقنية الفيديو (VAR)\n\n${line(m.home.score, m.away.score)}${tag}`);
    L.lastScore = [m.home.score, m.away.score];
  }

  if (!L.phases.ht && opt('halftime', true) && (/HALFTIME/.test(m.name) || /^(HT|Halftime)$/i.test(m.detail))) {
    posts.push(`⏸️ نهاية الشوط الأول\n\n${line(m.home.score, m.away.score)}${tag}`);
    L.phases.ht = true;
  }

  let finished = false;
  if (m.state === 'post' || m.completed) {
    finished = true;
    if (!L.phases.ft && opt('fulltime', true)) {
      const rm = rmHome ? m.home : m.away, op = rmHome ? m.away : m.home;
      let res = rm.score > op.score ? '✅ فوز ريال مدريد' : rm.score < op.score ? '❌ خسارة ريال مدريد' : '🤝 تعادل';
      if (rm.pens != null && op.pens != null) {
        res = `ركلات الترجيح: ${rm.pens} - ${op.pens} — ${rm.pens > op.pens ? '✅ تأهل ريال مدريد' : '❌ خروج ريال مدريد'}`;
      }
      const extra = /AET|extra/i.test(m.detail) ? ' (بعد الأشواط الإضافية)' : '';
      posts.push(`🔚 نهاية المباراة${extra}\n\n${line(m.home.score, m.away.score)}\n\n${res}${tag}`);
      L.phases.ft = true;
    }
  }

  for (const p of posts) {
    try { await postText(p); } catch (e) { console.error('❌ نشر حدث:', e.data ? JSON.stringify(e.data) : e.message); }
  }
  if (finished) L.finished = true;
  return finished;
}

// يفحص المباراة كل دقيقة لين تنتهي
export async function runLive(state, f, onTick) {
  state.live ??= {};
  const poll = opt('pollSeconds', 60) * 1000;
  const end = f.kickoff + opt('maxMinutes', 200) * 60000;
  console.log(`🔴 وضع مباشر: ريال مدريد × ${f.opponent.name}`);
  while (Date.now() < end) {
    let done = false;
    try { done = await tick(state, f); } catch (e) { console.warn('⚠️ مباشر:', e.message); }
    await onTick?.();
    if (done || DRY_RUN) break;
    await sleep(poll);
  }
  if (Date.now() >= end) state.live[f.id].finished = true;
  console.log('⚪ انتهى الوضع المباشر');
}
