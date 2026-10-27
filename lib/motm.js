// ⭐ أفضل لاعب في المباراة: يبحث عن الاختيار الرسمي بعد المباراة ويصمم له بطاقة
import { config } from './config.js';
import { askClaude, parseJson } from './claude.js';
import { motmHtml, renderPng, crestData } from './card.js';
import { postImage } from './x.js';

const opt = (k, d) => config.motm?.[k] ?? d;

async function findMotm(f) {
  const home = f.isHome ? 'Real Madrid' : f.opponent.fullName;
  const away = f.isHome ? f.opponent.fullName : 'Real Madrid';
  const prompt = `ابحث في الإنترنت عن أفضل لاعب في مباراة ${home} ضد ${away} (${f.competition}) التي لعبت ${new Date(f.kickoff).toISOString().slice(0, 10)}.

المطلوب الاختيار الرسمي فقط، بالترتيب:
1. اختيار الجهة المنظمة (مثل جائزة "MVP / Jugador del partido" من رابطة الليغا، أو "Player of the Match" من UEFA).
2. إذا لم يوجد اختيار رسمي، اختيار ريال مدريد الرسمي أو وسيلة إعلام كبرى (اذكر الاسم في source).
لا تخمّن. إذا لم تجد اختياراً واضحاً لهذه المباراة تحديداً، أرجع {"found": false}.

إذا وجدته، اذكر حتى 4 أرقام بارزة للاعب في المباراة من مصادر موثوقة (أهداف، تمريرات حاسمة، تصديات، تمريرات، مراوغات، تقييم...)، فقط إذا كنت متأكداً منها.

أرجع JSON فقط:
{"found":true,"player":"الاسم بالعربي كما تكتبه الصحافة العربية","playerLatin":"Name","team":"Real Madrid أو اسم الفريق الآخر بالإنجليزي","teamAr":"اسم الفريق بالعربي","source":"اسم الجهة بالعربي (مثل: رابطة الليغا)","stats":[{"label":"أهداف","value":"2"}],"homeScore":0,"awayScore":0,"homeAr":"","awayAr":"","competitionAr":"","url":"URL"}`;
  const j = parseJson(await askClaude(prompt, { webSearch: true, maxSearches: 5, maxTokens: 2000 }));
  return j.found && j.player ? j : null;
}

export async function runMotm(state, fixtures) {
  if (config.motm?.enabled === false) return;
  const [from, to] = opt('hoursAfter', [2.25, 12]);
  const retry = opt('retryMinutes', 45) * 60000;
  for (const f of fixtures) {
    const h = (Date.now() - f.kickoff) / 3600000;
    if (h < from || h > to) continue;
    const key = `${f.id}:motm`;
    if (state.done[key]) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < retry) continue;
    state.attempts[key] = Date.now();

    let j;
    try { j = await findMotm(f); } catch (e) { console.warn('⚠️ أفضل لاعب:', e.message); continue; }
    if (!j) { console.log('⏳ أفضل لاعب: لم يُعلن بعد'); continue; }

    const fin = state.live?.[f.id]?.final;
    const homeAr = fin?.home.name || j.homeAr, awayAr = fin?.away.name || j.awayAr;
    const hs = fin?.home.score ?? j.homeScore, as = fin?.away.score ?? j.awayScore;
    const matchLine = homeAr && awayAr && hs != null && as != null ? `${homeAr} ${hs} - ${as} ${awayAr}` : '';
    const isRMPlayer = /real madrid/i.test(j.team || '');
    const cr = config.crests || {};
    const crest = await crestData(isRMPlayer ? (cr['Real Madrid'] || f.rmCrest) : (cr[f.opponent.fullName] || cr[f.opponent.name] || f.opponent.crest));

    try {
      const png = await renderPng(motmHtml({
        player: j.player, teamName: j.teamAr || j.team, crest, matchLine,
        competitionAr: fin?.competitionAr || j.competitionAr || f.competition, kickoff: f.kickoff,
        stats: j.stats || [], source: j.source,
      }), { width: 1080, height: 1350 });
      const text = `⭐ أفضل لاعب في المباراة\n\n${j.player}${isRMPlayer ? ' 🤍' : ` (${j.teamAr || j.team})`}${matchLine ? `\n${matchLine}` : ''}${j.source ? `\n\nالاختيار: ${j.source}` : ''}\n\n#ريال_مدريد`;
      await postImage(text, png, `أفضل لاعب في المباراة: ${j.player}`, `motm-${f.id}.png`);
      state.done[key] = Date.now();
    } catch (e) { console.error('❌ أفضل لاعب:', e.data ? JSON.stringify(e.data) : e.message); }
  }
}
