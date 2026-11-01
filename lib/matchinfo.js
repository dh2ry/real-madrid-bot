// 📆 تغريدة «المباراة القادمة» بالشكل المعتمد:
// 🏆 الليغا : الجولة الثانية 🏆
// ⚽️ ألميريا : ريال مدريد
// 📆 السبت ١٩-٠٨-٢٠٢٣
// ⏰ الساعة ٨:٣٠ م بتوقيت مكة
// 📺 قناة beIN SPORTS HD 1
// 🏟️ ملعب باور هورس
// 🎙 تعليق علي محمد علي
import { config } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { postText } from './x.js';
import { arabicNames } from './extras.js';

const opt = (k, d) => config.matchInfo?.[k] ?? d;
const TZ = () => config.timezone || 'Asia/Riyadh';
const arDigits = (s) => String(s).replace(/\d/g, (d) => '٠١٢٣٤٥٦٧٨٩'[d]);

// اسم البطولة المختصر
const COMP = {
  'Primera Division': 'الليغا', 'UEFA Champions League': 'دوري أبطال أوروبا', 'Copa del Rey': 'كأس ملك إسبانيا',
  'Supercopa de España': 'كأس السوبر الإسباني', 'FIFA Club World Cup': 'كأس العالم للأندية', 'UEFA Super Cup': 'كأس السوبر الأوروبي',
};
const STAGE = {
  LEAGUE_STAGE: null, GROUP_STAGE: null, PLAYOFFS: 'الملحق', LAST_32: 'دور الـ32', LAST_16: 'دور الـ16',
  QUARTER_FINALS: 'ربع النهائي', SEMI_FINALS: 'نصف النهائي', FINAL: 'النهائي', THIRD_PLACE: 'تحديد المركز الثالث',
};

// الجولة بالعربي: الأولى، الثانية … العشرون، الحادية والعشرون …
const ONES = ['', 'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة'];
const UNITS = ['', 'الحادية', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة'];
const TENS = { 2: 'العشرون', 3: 'الثلاثون', 4: 'الأربعون' };
export function ordinalAr(n) {
  if (n <= 10) return ONES[n];
  if (n < 20) return `${UNITS[n - 10]} عشرة`;
  const t = Math.floor(n / 10), u = n % 10;
  if (!TENS[t]) return arDigits(n);
  return u ? `${UNITS[u]} و${TENS[t]}` : TENS[t];
}

function roundLine(f, foundRound) {
  const comp = COMP[f.competition] || f.competition;
  let round = f.round || foundRound || null;
  if (!round && f.stage && STAGE[f.stage]) round = STAGE[f.stage];
  if (!round && f.matchday) round = `الجولة ${ordinalAr(f.matchday)}`;
  return round ? `${comp} : ${round}` : comp;
}

// القناة والمعلق والملعب (بحث في الإنترنت)
async function findBroadcast(f, state) {
  const home = f.isHome ? 'Real Madrid' : f.opponent.fullName;
  const away = f.isHome ? f.opponent.fullName : 'Real Madrid';
  const j = parseJson(await askClaude(`ابحث في الإنترنت عن معلومات بث مباراة ${home} ضد ${away} (${f.competition}) يوم ${new Date(f.kickoff).toISOString().slice(0, 10)}:
1. القناة الناقلة في منطقة الشرق الأوسط وشمال أفريقيا (غالباً beIN SPORTS): اسم القناة بالضبط مثل "beIN SPORTS HD 1".
2. المعلق العربي على المباراة.
3. اسم الملعب كما يكتبه الإعلام العربي.
4. اسم الفريقين بالعربي كما يكتبه الإعلام العربي.
فقط معلومات مؤكدة من مصادر موثوقة (جدول beIN، صحف ومواقع رياضية عربية). إذا ما تأكدت من معلومة اتركها فاضية "".
أرجع JSON فقط: {"channel":"","commentator":"","stadium":"","homeAr":"","awayAr":"","round":""}
(round: اتركه فاضي إلا إذا كانت مرحلة إقصائية مثل "دور الـ16")`, { webSearch: true, maxSearches: 5, maxTokens: 1200 }));
  return j;
}

function buildTweet(f, info) {
  const homeAr = info.homeAr || (f.isHome ? 'ريال مدريد' : f.opponent.name);
  const awayAr = info.awayAr || (f.isHome ? f.opponent.name : 'ريال مدريد');
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-GB', { timeZone: TZ(), day: '2-digit', month: '2-digit', year: 'numeric' })
    .formatToParts(f.kickoff).map((x) => [x.type, x.value]));
  const weekday = new Intl.DateTimeFormat('ar', { timeZone: TZ(), weekday: 'long' }).format(f.kickoff);
  const time = new Intl.DateTimeFormat('ar-u-nu-arab', { timeZone: TZ(), hour: 'numeric', minute: '2-digit', hour12: true }).format(f.kickoff);
  const stadium = info.stadium || f.venue;
  const lines = [
    `🏆 ${roundLine(f, info.round)} 🏆`,
    `⚽️ ${homeAr} : ${awayAr}`,
    `📆 ${weekday} ${arDigits(`${parts.day}-${parts.month}-${parts.year}`)}`,
    `⏰ الساعة ${time} بتوقيت مكة`,
    info.channel && `📺 قناة ${info.channel}`,
    stadium && `🏟️ ${/^ملعب/.test(stadium) ? stadium : `ملعب ${stadium}`}`,
    info.commentator && `🎙 تعليق ${info.commentator}`,
  ].filter(Boolean);
  return lines.join('\n');
}

export async function runMatchInfo(state, fixtures) {
  if (config.matchInfo?.enabled === false) return;
  const hour = opt('hour', 10), before = opt('hoursBefore', 6), waitUntil = opt('waitForCommentatorHours', 4);
  for (const f of fixtures) {
    if (f.kickoff < Date.now()) continue;
    const key = `${f.id}:matchinfo`;
    if (state.done[key]) continue;
    // الساعة 10 الصبح يوم المباراة (بتوقيت مكة)، أو قبلها بـ 6 ساعات لو المباراة بدري
    const dayStr = new Intl.DateTimeFormat('en-CA', { timeZone: TZ() }).format(f.kickoff);
    const at10 = Date.parse(`${dayStr}T${String(hour).padStart(2, '0')}:00:00+03:00`);
    const startAt = Math.min(at10, f.kickoff - before * 3600000);
    if (Date.now() < startAt) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < 55 * 60000) continue;
    state.attempts[key] = Date.now();

    let info = {};
    try { info = await findBroadcast(f, state); } catch (e) { console.warn('⚠️ معلومات البث:', e.message); }
    const hoursLeft = (f.kickoff - Date.now()) / 3600000;
    if ((!info.channel || !info.commentator) && hoursLeft > waitUntil) {
      console.log(`⏳ المباراة القادمة: ${!info.channel ? 'القناة' : 'المعلق'} لسه ما انعلن، نعيد المحاولة بعد ساعة`);
      continue;
    }
    if (!info.homeAr || !info.awayAr) {
      const ar = await arabicNames(state, [f.opponent.name]);
      const opp = ar(f.opponent.name);
      info.homeAr ||= f.isHome ? 'ريال مدريد' : opp;
      info.awayAr ||= f.isHome ? opp : 'ريال مدريد';
    }
    const text = buildTweet(f, info);
    if (!fitsTweet(text)) { console.warn('⚠️ تغريدة المباراة القادمة طويلة'); continue; }
    try { await postText(text); state.done[key] = Date.now(); } catch (e) { console.error('❌ المباراة القادمة:', e.data ? JSON.stringify(e.data) : e.message); }
  }
}

export { buildTweet as _buildMatchInfoTweet };
