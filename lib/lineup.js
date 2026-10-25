// التشكيلة الرسمية: تُنشر كصورة مصممة قبل المباراة بحوالي ساعة
import { config, env, fmtTime } from './config.js';
import { askClaude, parseJson } from './claude.js';
import { lineupHtml, renderPng, crestData } from './card.js';
import { postImage } from './x.js';

const AF_RM_ID = 541; // رقم ريال مدريد في API-Football

async function af(path) {
  const res = await fetch(`https://v3.football.api-sports.io${path}`, { headers: { 'x-apisports-key': env.APIFOOTBALL_KEY } });
  const j = await res.json();
  if (j.errors && Object.keys(j.errors).length) throw new Error(JSON.stringify(j.errors));
  return j.response;
}

// المصدر 1: API-Football (إذا عندك مفتاح)
async function fromApiFootball(f, state) {
  if (!env.APIFOOTBALL_KEY) return null;
  let afId = state.afIds[f.id];
  if (!afId) {
    const date = new Date(f.kickoff).toISOString().slice(0, 10);
    const list = await af(`/fixtures?team=${AF_RM_ID}&date=${date}`);
    afId = list[0]?.fixture?.id;
    if (!afId) return null;
    state.afIds[f.id] = afId;
  }
  const teams = await af(`/fixtures/lineups?fixture=${afId}`);
  const rm = teams.find((t) => t.team?.id === AF_RM_ID);
  if (!rm || rm.startXI?.length !== 11) return null;

  const rows = new Map();
  const order = { G: 1, D: 2, M: 3, F: 4 };
  for (const { player: p } of rm.startXI) {
    const [r, c] = (p.grid || `${order[p.pos] || 3}:9`).split(':').map(Number);
    if (!rows.has(r)) rows.set(r, []);
    rows.get(r).push({ name: p.name, number: p.number, c });
  }
  const lines = [...rows.entries()].sort((a, b) => a[0] - b[0])
    .map(([, ps]) => ps.sort((a, b) => b.c - a.c).map(({ name, number }) => ({ name, number })));
  return {
    source: 'API-Football',
    formation: rm.formation,
    coach: rm.coach?.name,
    lines,
    subs: (rm.substitutes || []).map(({ player: p }) => ({ name: p.name, number: p.number })),
  };
}

// المصدر 2: Claude يبحث عن التشكيلة الرسمية المعلنة
async function fromWebSearch(f) {
  const prompt = `ابحث في الإنترنت عن التشكيلة الأساسية الرسمية لريال مدريد في مباراة اليوم ضد ${f.opponent.fullName} (${f.competition}) التي تبدأ ${new Date(f.kickoff).toISOString()} بتوقيت UTC.

قواعد صارمة:
- فقط التشكيلة التي أعلنها النادي رسمياً لهذه المباراة (حساب النادي أو موقعه أو وسائل إعلام كبرى تنقل الإعلان الرسمي). التشكيلات المتوقعة أو المحتملة مرفوضة.
- إذا لم تُعلن بعد أو غير متأكد، أرجع {"found": false}.
- رتّب اللاعبين في خطوط: الحارس أولاً، ثم الدفاع، ثم الوسط، ثم الهجوم. داخل كل خط رتّبهم من اليسار إلى اليمين (الظهير الأيسر أولاً).
- المجموع لازم 11 لاعباً بالضبط.

أرجع JSON فقط:
{"found":true,"formation":"4-3-3","coach":"Name","lines":[[{"name":"Courtois","number":1}],[...],[...],[...]],"subs":[{"name":"...","number":13}],"source":"URL"}`;
  const j = parseJson(await askClaude(prompt, { webSearch: true, maxSearches: 4, maxTokens: 2500 }));
  if (!j.found || !Array.isArray(j.lines)) return null;
  const count = j.lines.flat().length;
  if (count !== 11 || j.lines[0]?.length !== 1) { console.warn(`⚠️ تشكيلة غير صالحة من البحث (${count} لاعب)`); return null; }
  return { ...j, source: j.source || 'web' };
}

// ترجمة الأسماء للعربية
async function translate(lineup, f) {
  const names = [...lineup.lines.flat(), ...(lineup.subs || [])].map((p) => p.name);
  const prompt = `ترجم إلى العربية كما تكتبها وسائل الإعلام الرياضية العربية. للاعبين استخدم الاسم المختصر الشائع (مثل: كورتوا، فينيسيوس، مبابي، بيلينغهام)، ولا تتجاوز كلمتين.
اللاعبون: ${JSON.stringify(names)}
المدرب: ${JSON.stringify(lineup.coach || '')}
الفريق المنافس: ${JSON.stringify(f.opponent.fullName)}
البطولة: ${JSON.stringify(f.competition)}
أرجع JSON فقط: {"players":{"English":"عربي"},"coach":"","opponent":"","competition":""}`;
  const j = parseJson(await askClaude(prompt, { maxTokens: 1500 }));
  const ar = (p) => ({ ...p, name: j.players?.[p.name] || p.name });
  return {
    ...lineup,
    lines: lineup.lines.map((l) => l.map(ar)),
    subs: (lineup.subs || []).map(ar),
    coachAr: j.coach || lineup.coach,
    opponentAr: j.opponent || f.opponent.name,
    competitionAr: j.competition || f.competition,
  };
}

export async function buildLineupPost(f, t) {
  const crests = config.crests || {};
  const [rmCrest, opponentCrest] = await Promise.all([
    crestData(crests['Real Madrid'] || f.rmCrest),
    crestData(crests[f.opponent.fullName] || crests[f.opponent.name] || f.opponent.crest),
  ]);
  const data = { ...t, kickoff: f.kickoff, isHome: f.isHome, rmCrest, opponentCrest, venue: f.venue };
  const png = await renderPng(lineupHtml(data));
  const text = `📋 التشكيلة الرسمية لريال مدريد أمام ${t.opponentAr}
🏆 ${t.competitionAr}
⏰ ${fmtTime(f.kickoff)} ${config.timezoneLabel || ''}

#ريال_مدريد`;
  const alt = `تشكيلة ريال مدريد (${t.formation || ''}): ${t.lines.flat().map((p) => p.name).join('، ')}`;
  return { png, text, alt };
}

export async function publishLineup(f, lineup) {
  const { png, text, alt } = await buildLineupPost(f, await translate(lineup, f));
  await postImage(text, png, alt, `lineup-${f.id}.png`);
}

export async function runLineup(state, fixtures) {
  if (config.lineup?.enabled === false) return;
  const startBefore = config.lineup?.startMinutesBefore ?? 75;
  const searchBefore = config.lineup?.webSearchFallbackMinutesBefore ?? 55;
  for (const f of fixtures) {
    const key = `${f.id}:lineup`;
    if (state.done[key]) continue;
    const mins = (f.kickoff - Date.now()) / 60000;
    if (mins > startBefore || mins < -20) continue;

    let lineup = await fromApiFootball(f, state).catch((e) => { console.warn('⚠️ API-Football:', e.message); return null; });
    if (!lineup && mins <= searchBefore) {
      lineup = await fromWebSearch(f).catch((e) => { console.warn('⚠️ بحث التشكيلة:', e.message); return null; });
    }
    if (!lineup) { console.log(`⏳ التشكيلة ضد ${f.opponent.name} لم تُعلن بعد (${Math.round(mins)} دقيقة على البداية)`); continue; }

    console.log(`📋 التشكيلة من ${lineup.source}`);
    await publishLineup(f, lineup);
    state.done[key] = Date.now();
  }
}
