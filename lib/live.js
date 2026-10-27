// أحداث المباراة المباشرة (أهداف، بطاقات، بداية، استراحة، نهاية) من بيانات ESPN
import { config, DRY_RUN } from './config.js';
import { askClaude, parseJson } from './claude.js';
import { postText, postImage } from './x.js';
import { resultHtml, statsHtml, renderPng, crestData } from './card.js';

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
    const sub = /substitution/.test(t);
    if (sub) {
      // "Substitution, Real Madrid. Rodrygo replaces Vinícius Júnior (because of an injury)."
      const txt = k.text || '';
      const mm = txt.match(/\.\s*(.+?) replaces (.+?)(?: because of an injury)?\.?$/i);
      const ps = (k.participants || []).map((p) => p.athlete?.displayName).filter(Boolean);
      out.push({
        type: { id: k.type?.id || 'sub', text: 'Substitution' }, clock: k.clock, team: k.team, substitution: true,
        subOn: mm?.[1]?.trim() || ps[0], subOff: mm?.[2]?.trim() || ps[1], injurySub: /injury/i.test(txt),
        athletesInvolved: (k.participants || []).map((p) => p.athlete).filter(Boolean),
      });
      continue;
    }
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
  // 🚑 الإصابات من التعليق: "Delay in match because of an injury Kylian Mbappé (Real Madrid)."
  for (const c of j.commentary || []) {
    const txt = c.text || '';
    const mm = txt.match(/because of an injury(?: to)? (.+?) \((.+?)\)/i);
    if (!mm || /replaces/i.test(txt)) continue;
    out.push({
      type: { id: 'injury', text: 'Injury' }, clock: { displayValue: c.time?.displayValue || '' }, injury: true,
      teamName: mm[2].trim(), athletesInvolved: [{ id: `inj-${mm[1].trim()}-${c.time?.displayValue || ''}`, displayName: mm[1].trim() }],
    });
  }
  const clock = j.header?.competitions?.[0]?.status?.displayClock;
  const box = {};
  for (const t of j.boxscore?.teams || []) {
    const map = {};
    for (const st of t.statistics || []) map[(st.name || st.label || '').toLowerCase()] = st.displayValue ?? st.value;
    box[String(t.team?.id)] = map;
  }
  return { events: out, clock, box };
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

// صفوف الإحصائيات (الاسم في ESPN ← العنوان بالعربي)
const STAT_ROWS = [
  [['possessionpct', 'possession'], 'الاستحواذ', true],
  [['totalshots', 'shots'], 'التسديدات'],
  [['shotsontarget', 'on goal', 'ontarget'], 'على المرمى'],
  [['woncorners', 'corner kicks', 'corners'], 'الركنيات'],
  [['totalpasses', 'passes'], 'التمريرات'],
  [['passpct', 'pass completion %', 'accuratepassespct'], 'دقة التمرير', true],
  [['foulscommitted', 'fouls'], 'الأخطاء'],
  [['offsides'], 'التسلل'],
  [['saves'], 'التصديات'],
  [['yellowcards'], 'البطاقات الصفراء'],
  [['redcards'], 'البطاقات الحمراء'],
];
function statRows(m) {
  const H = m.box?.[m.home.id], A = m.box?.[m.away.id];
  if (!H || !A) return [];
  const pick = (map, keys) => { for (const k of keys) if (map[k] != null && map[k] !== '') return String(map[k]).replace('%', ''); return null; };
  const rows = [];
  for (const [keys, label, pct] of STAT_ROWS) {
    const h = pick(H, keys), a = pick(A, keys);
    if (h == null || a == null) continue;
    if (label === 'البطاقات الحمراء' && +h === 0 && +a === 0) continue;
    rows.push({ label, h, a, pct: !!pct });
  }
  return rows.slice(0, 9);
}

export function shouldGoLive(f, state) {
  if (config.live?.enabled === false || state.live?.[f.id]?.finished) return false;
  const mins = (Date.now() - f.kickoff) / 60000;
  return mins >= -(opt('startMinutesBefore', 15)) && mins <= opt('maxMinutes', 185);
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
    m.box = sum.box;
  } catch (e) { console.warn('⚠️ تفاصيل المباراة:', e.message); }
  console.log(`📊 ${m.home.name} ${m.home.score}-${m.away.score} ${m.away.name} | ${m.detail} | أحداث: ${m.details.length}`);
  const nowMin = parseInt(String(m.clock || m.detail).replace(/[^\d+]/g, '')) || 0;

  const tag = '\n\n#ريال_مدريد';
  const rmHome = isRM(m.home.name);
  const ar = await arabic(state, [m.home.name, m.away.name, f.competition, ...m.details.flatMap((d) => [d.athletesInvolved?.[0]?.displayName, d.subOn, d.subOff])]);
  const H = ar(m.home.name), A = ar(m.away.name);
  const line = (h, a) => `${H} ${h} - ${a} ${A}`;
  const posts = [];

  L.lastScore ??= [0, 0];
  if (!L.phases.kickoff && opt('kickoff', true)) {
    // ما ننشر «انطلقت» لو البوت دخل والمباراة شغالة من زمان
    if (nowMin <= 10) posts.push({ text: `🏁 انطلقت المباراة\n\n${H} × ${A}${tag}`, phase: 'kickoff' });
    else L.phases.kickoff = true;
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

    const isRMTeam = d.injury ? isRM(d.teamName) : (String(d.team?.id) === m.home.id) === rmHome;
    const stale = nowMin && parseInt(minute(d)) < nowMin - 15;

    if (d.substitution) {
      if (!stale && (isRMTeam ? opt('substitutions', true) : opt('opponentSubstitutions', false))) {
        text = `🔄 تبديل في ${teamName}\n\n⬆️ دخول: ${ar(d.subOn) || '—'}\n⬇️ خروج: ${ar(d.subOff) || '—'}${d.injurySub ? '\n🚑 بسبب الإصابة' : ''}${min}${tag}`;
      }
    } else if (d.injury) {
      if (!stale && (isRMTeam ? opt('injuries', true) : opt('opponentInjuries', false))) {
        text = `🚑 إصابة\n\n${player} (${isRMTeam ? 'ريال مدريد' : ar(d.teamName)})${min}${tag}`;
      }
    } else if (d.scoringPlay) {
      const s = goalScores.get(k) || { h: m.home.score, a: m.away.score, teamId: String(d.team?.id) };
      const forRM = (s.teamId === m.home.id) === rmHome;
      const how = d.ownGoal ? ' (هدف عكسي)' : d.penaltyKick ? ' (ركلة جزاء)' : '';
      const who = d.ownGoal ? `هدف عكسي عن طريق ${player}` : player + how;
      L.generic ??= [];
      if (L.generic.includes(`${s.h}-${s.a}`)) {
        // الهدف انتشر قبل من تغيّر النتيجة، الحين نعرف صاحبه
        L.generic = L.generic.filter((x) => x !== `${s.h}-${s.a}`);
        text = player ? `⚽️ صاحب الهدف: ${who}${min}\n\n${line(s.h, s.a)}${tag}` : null;
      } else text = forRM
        ? `⚽️ قوووووول لريال مدريد!\n\n${d.ownGoal ? `هدف عكسي عن طريق ${player}` : player + how}${min}\n\n${line(s.h, s.a)}${tag}`
        : `⚽️ هدف لـ${s.teamId === m.home.id ? H : A}\n\n${d.ownGoal ? `هدف عكسي عن طريق ${player}` : player + how}${min}\n\n${line(s.h, s.a)}${tag}`;
      L.lastScore = [s.h, s.a];
    } else if (d.redCard && opt('redCards', true)) {
      text = `🟥 بطاقة حمراء!\n\n${player} (${teamName})${min}${tag}`;
    } else if (d.yellowCard && stale) {
      text = null; // بطاقة صفراء قديمة (البوت بدأ متأخر) — ما ننشرها
    } else if (d.yellowCard) {
      if (isRMTeam ? opt('yellowCards', true) : opt('opponentYellowCards', true)) {
        text = `🟨 بطاقة صفراء\n\n${player} (${teamName})${min}${tag}`;
      }
    }
    console.log(`🧾 ${d.type?.text || '?'} ${minute(d)}' ${d.athletesInvolved?.[0]?.displayName || d.subOn || ''} → ${text ? 'نشر' : 'تجاهل'}`);
    if (text) posts.push({ text, key: k });
    else L.posted.push(k);
  }

  // ⚽ احتياط: النتيجة زادت بدون ما يجي حدث هدف (ESPN تأخرت في التفاصيل)
  const addGoals = (side, from, to) => {
    for (let n = from + 1; n <= to; n++) {
      const h = side === 'h' ? n : L.lastScore[0], a = side === 'a' ? n : L.lastScore[1];
      const forRM = (side === 'h') === rmHome;
      posts.push({ text: forRM ? `⚽️ قوووووول لريال مدريد!\n\n${line(h, a)}${tag}` : `⚽️ هدف لـ${side === 'h' ? H : A}\n\n${line(h, a)}${tag}` });
      L.lastScore = [h, a];
      (L.generic ??= []).push(`${h}-${a}`);
      console.log(`🧾 هدف من تغيّر النتيجة → نشر (${h}-${a})`);
    }
  };
  if (m.home.score > L.lastScore[0]) addGoals('h', L.lastScore[0], m.home.score);
  if (m.away.score > L.lastScore[1]) addGoals('a', L.lastScore[1], m.away.score);

  // ❌ هدف ملغي (VAR): النتيجة نزلت عن آخر نتيجة نشرناها
  if (L.lastScore && m.home.score + m.away.score < L.lastScore[0] + L.lastScore[1]) {
    posts.push({ text: `❌ إلغاء الهدف بعد العودة لتقنية الفيديو (VAR)\n\n${line(m.home.score, m.away.score)}${tag}` });
    L.lastScore = [m.home.score, m.away.score];
  }

  if (!L.phases.ht && opt('halftime', true) && (/HALFTIME/.test(m.name) || /^(HT|Halftime)$/i.test(m.detail))) {
    posts.push({ text: `⏸️ نهاية الشوط الأول\n\n${line(m.home.score, m.away.score)}${tag}`, phase: 'ht' });
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
      const ftText = `🔚 نهاية المباراة${extra}\n\n${line(m.home.score, m.away.score)}\n\n${res}${tag}`;
      let image = null;
      if (opt('resultCard', true)) {
        try {
          const scorers = { [m.home.id]: [], [m.away.id]: [] };
          for (const d of m.details) {
            if (!d.scoringPlay || d.shootout) continue;
            const g = goalScores.get(keyOf(d));
            (scorers[g?.teamId || String(d.team?.id)] ||= []).push({
              name: ar(d.athletesInvolved?.[0]?.displayName) || '', min: minute(d),
              note: d.ownGoal ? '(عكسي)' : d.penaltyKick ? '(جزاء)' : '',
            });
          }
          const cr = config.crests || {};
          const rmC = await crestData(cr['Real Madrid'] || f.rmCrest);
          const opC = await crestData(cr[f.opponent.fullName] || cr[f.opponent.name] || f.opponent.crest);
          const team = (t) => ({ name: ar(t.name), score: t.score, scorers: scorers[t.id] || [], crest: isRM(t.name) ? rmC : opC });
          const html = resultHtml({ competitionAr: ar(f.competition), kickoff: f.kickoff, result: res.replace(/^[^\p{L}]+/u, ''), extra: extra.trim(), home: team(m.home), away: team(m.away) });
          image = await renderPng(html, { width: 1080, height: 1080 });
        } catch (e) { console.warn('⚠️ بطاقة النتيجة:', e.message); }
      }
      posts.push({ text: ftText, image, alt: `النتيجة النهائية: ${line(m.home.score, m.away.score)}`, file: `result-${f.id}.png`, phase: 'ft' });
      L.final = { home: { name: ar(m.home.name), score: m.home.score, isRM: rmHome }, away: { name: ar(m.away.name), score: m.away.score, isRM: !rmHome }, competitionAr: ar(f.competition) };

      // 📊 بطاقة إحصائيات المباراة
      const rows = statRows(m);
      if (opt('statsCard', true) && rows.length >= 4 && !L.phases.stats) {
        try {
          const cr = config.crests || {};
          const rmC = await crestData(cr['Real Madrid'] || f.rmCrest);
          const opC = await crestData(cr[f.opponent.fullName] || cr[f.opponent.name] || f.opponent.crest);
          const t = (x) => ({ name: ar(x.name), score: x.score, crest: isRM(x.name) ? rmC : opC });
          const png = await renderPng(statsHtml({ competitionAr: ar(f.competition), kickoff: f.kickoff, home: t(m.home), away: t(m.away), rows }), { width: 1080, height: 1350 });
          posts.push({ text: `📊 المباراة بالأرقام\n\n${line(m.home.score, m.away.score)}${tag}`, image: png, alt: 'إحصائيات المباراة', file: `stats-${f.id}.png`, phase: 'stats' });
        } catch (e) { console.warn('⚠️ بطاقة الإحصائيات:', e.message); }
      } else if (opt('statsCard', true)) console.warn(`⚠️ الإحصائيات غير متوفرة من ESPN (${rows.length} صفوف)`);
    }
  }

  // ننشر، ونسجّل الحدث «منشور» بس لو نجح. لو فشل نعيد المحاولة بالدقيقة الجاية (حتى 3 مرات)
  L.fail ??= {};
  for (const p of posts) {
    const id = p.key || p.phase || p.text;
    try {
      if (p.image) await postImage(p.text, p.image, p.alt, p.file);
      else await postText(p.text);
      if (p.key) L.posted.push(p.key);
      if (p.phase) L.phases[p.phase] = true;
      delete L.fail[id];
    } catch (e) {
      console.error('❌ نشر حدث:', e.data ? JSON.stringify(e.data) : e.message);
      L.fail[id] = (L.fail[id] || 0) + 1;
      if (L.fail[id] >= 3) { if (p.key) L.posted.push(p.key); if (p.phase) L.phases[p.phase] = true; }
    }
  }
  // المباراة تعتبر منتهية بعد ما ننشر النهاية (أو لو النهاية مطفية)
  if (finished && (L.phases.ft || !opt('fulltime', true))) { L.finished = true; return true; }
  return false;
}

// يفحص المباراة كل دقيقة لين تنتهي
export async function runLive(state, f, onTick) {
  state.live ??= {};
  const poll = opt('pollSeconds', 60) * 1000;
  const end = f.kickoff + opt('maxMinutes', 185) * 60000;
  console.log(`🔴 وضع مباشر: ريال مدريد × ${f.opponent.name}`);
  let busy = null, pending = null;
  while (Date.now() < end) {
    let done = false;
    // كل فحص له حد أقصى 3 دقائق، عشان لو علق طلب ما يوقف متابعة المباراة
    // وما نبدأ فحص جديد والقديم لسه شغّال (عشان ما ينشرون نفس الحدث مرتين)
    let timer;
    if (!pending) pending = tick(state, f).finally(() => { pending = null; });
    try {
      done = await Promise.race([pending, new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('الفحص طوّل أكثر من 3 دقائق، ننتظره')), 180000); })]);
    } catch (e) { console.warn('⚠️ مباشر:', e.message); } finally { clearTimeout(timer); }
    // الأخبار تشتغل بالخلفية عشان ما تأخر متابعة المباراة
    if (!busy) { busy = Promise.resolve(onTick?.()).catch(() => {}).finally(() => { busy = null; }); }
    if (done || DRY_RUN) { await busy; break; }
    await sleep(poll);
  }
  if (Date.now() >= end) state.live[f.id].finished = true;
  console.log('⚪ انتهى الوضع المباشر');
}
