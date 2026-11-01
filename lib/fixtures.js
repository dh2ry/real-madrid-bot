// جدول مباريات ريال مدريد من football-data.org (الليغا + دوري الأبطال مجاناً)
import { config, env } from './config.js';

const RM_ID = 86; // رقم ريال مدريد في football-data.org
const day = (offset) => new Date(Date.now() + offset * 86400000).toISOString().slice(0, 10);

function fromApi(m) {
  const isHome = m.homeTeam.id === RM_ID;
  const opp = isHome ? m.awayTeam : m.homeTeam;
  return {
    id: String(m.id),
    kickoff: Date.parse(m.utcDate),
    status: m.status,
    competition: m.competition?.name || '',
    isHome,
    opponent: { name: opp.shortName || opp.name, fullName: opp.name, crest: opp.crest },
    rmCrest: (isHome ? m.homeTeam : m.awayTeam).crest,
    venue: m.venue || null,
    score: m.score?.fullTime ?? null,
    matchday: m.matchday ?? null,
    stage: m.stage || null,
  };
}

// مباريات تضيفها يدوياً في config.json (مثل كأس الملك والسوبر لأنها مو في الخطة المجانية)
// الوقت يُكتب بتوقيت مكة (مثل 2026-12-17T23:00). لو ما فيه منطقة زمنية نعتبره +03:00
const meccaTime = (s) => Date.parse(/Z|[+-]\d\d:?\d\d$/.test(s) ? s : `${s}+03:00`);
function extraFixtures() {
  return (config.extraFixtures || []).map((f, i) => ({
    id: `extra-${f.kickoff}`,
    kickoff: meccaTime(f.kickoff),
    status: 'SCHEDULED',
    competition: f.competition || '',
    isHome: f.isHome !== false,
    opponent: { name: f.opponent, fullName: f.opponent, crest: f.opponentCrest || null },
    rmCrest: 'https://crests.football-data.org/86.png',
    venue: f.venue || null,
    score: null,
    round: f.round || null, // مثل "دور الـ16" للمباريات اليدوية
  }));
}

export async function getFixtures(state) {
  const cached = state.fixtures;
  const stale = !cached || Date.now() - cached.fetchedAt > 6 * 3600000;
  if (stale && env.FOOTBALL_DATA_KEY) {
    try {
      const url = `https://api.football-data.org/v4/teams/${RM_ID}/matches?dateFrom=${day(-3)}&dateTo=${day(14)}`;
      const res = await fetch(url, { headers: { 'X-Auth-Token': env.FOOTBALL_DATA_KEY }, signal: AbortSignal.timeout(20000) });
      if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
      const { matches } = await res.json();
      state.fixtures = { fetchedAt: Date.now(), list: matches.map(fromApi) };
      console.log(`📅 تم تحديث الجدول: ${matches.length} مباراة`);
    } catch (e) {
      console.warn('⚠️ فشل جلب جدول المباريات:', e.message);
    }
  } else if (!env.FOOTBALL_DATA_KEY && stale) {
    console.warn('⚠️ FOOTBALL_DATA_KEY غير موجود — التشكيلة والمؤتمرات تعتمد على extraFixtures فقط');
  }
  const byId = new Map((state.fixtures?.list || []).map((f) => [f.id, f])); // يشيل التكرار
  const list = [...byId.values()];
  if (state.fixtures) state.fixtures.list = list;
  const ids = new Set(list.map((f) => f.kickoff));
  return [...list, ...extraFixtures().filter((f) => !ids.has(f.kickoff))]
    .filter((f) => !['POSTPONED', 'CANCELLED', 'SUSPENDED'].includes(f.status))
    .sort((a, b) => a.kickoff - b.kickoff);
}
