// إضافات المحتوى: في مثل هذا اليوم، جدول الترتيب، الغيابات، الأرقام القياسية، ملخص الأسبوع
import { config, env, localNow, dailyDue } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { onThisDayHtml, standingsHtml, absencesHtml, topicHtml, renderPng, crestData } from './card.js';
import { postText, postImage, postThreadWithImage } from './x.js';

const opt = (sec, k, d) => config[sec]?.[k] ?? d;
const on = (sec) => config[sec]?.enabled !== false;
const RM_CREST = () => (config.crests || {})['Real Madrid'] || 'https://crests.football-data.org/86.png';
const TAG = '\n\n#ريال_مدريد';
const err = (label, e) => console.error(`❌ ${label}:`, e.data ? JSON.stringify(e.data) : e.message);

// ترجمة أسماء الأندية/اللاعبين (مشتركة مع الوضع المباشر عبر state.names)
async function arabicNames(state, names) {
  state.names ??= { 'Real Madrid': 'ريال مدريد' };
  const missing = [...new Set(names.filter((n) => n && !state.names[n]))];
  if (missing.length) {
    try {
      Object.assign(state.names, parseJson(await askClaude(`ترجم أسماء أندية/لاعبي كرة القدم هذه إلى العربية كما تكتبها وسائل الإعلام الرياضية العربية، بالاسم الشائع المختصر:
${JSON.stringify(missing)}
أرجع JSON فقط: {"English":"عربي"}`, { maxTokens: 1500 })));
    } catch (e) { console.warn('⚠️ ترجمة الأسماء:', e.message); }
  }
  return (n) => state.names[n] || n;
}

// ───────────── 📅 في مثل هذا اليوم ─────────────
export async function runOnThisDay(state) {
  if (!on('onThisDay')) return;
  const key = dailyDue(state, 'onthisday', opt('onThisDay', 'hour', 12));
  if (!key) return;
  const n = localNow();
  const dateEn = new Date(Date.UTC(2000, n.month - 1, n.day)).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', timeZone: 'UTC' });
  const dateAr = new Intl.DateTimeFormat('ar-u-nu-latn', { day: 'numeric', month: 'long', timeZone: 'UTC' }).format(new Date(Date.UTC(2000, n.month - 1, n.day)));
  const recent = (state.otdUsed || []).slice(-30);
  try {
    const j = parseJson(await askClaude(`ابحث في الإنترنت عن حدث تاريخي مهم ومؤكد لنادي ريال مدريد (كرة القدم) وقع في يوم ${dateEn} (نفس اليوم والشهر، أي سنة سابقة).
الأولوية: ألقاب، نهائيات، انتصارات تاريخية، صفقات أسطورية، أرقام قياسية، أول مباراة لأسطورة.
تجنب هذه الأحداث المنشورة سابقاً: ${JSON.stringify(recent)}
يجب أن يكون التاريخ (اليوم والشهر) مؤكداً من مصدر موثوق. إذا لم تجد حدثاً مؤكداً أرجع {"found": false}.

أرجع JSON فقط:
{"found":true,"year":1960,"title":"عنوان قصير وقوي (حتى 8 كلمات)","text":"جملتان تشرحان الحدث (حتى 220 حرفاً)","tweet":"تغريدة تبدأ بـ 📅 في مثل هذا اليوم من عام ... (حتى 230 حرفاً)","source":"URL"}`, { webSearch: true, maxSearches: 5, maxTokens: 1500 }));
    if (!j.found) { console.log('⏳ في مثل هذا اليوم: ما لقى حدث مؤكد'); state.done[key] = Date.now(); return; }
    const crest = await crestData(RM_CREST());
    const png = await renderPng(onThisDayHtml({ dateAr, year: j.year, ago: new Date().getFullYear() - Number(j.year), title: j.title, text: j.text, crest }), { width: 1080, height: 1080 });
    const text = fitsTweet(j.tweet + TAG) ? j.tweet + TAG : `📅 في مثل هذا اليوم من عام ${j.year}\n\n${j.title}${TAG}`;
    await postImage(text, png, `في مثل هذا اليوم ${j.year}: ${j.title}`, 'onthisday.png');
    (state.otdUsed ||= []).push(`${j.year}: ${j.title}`);
    state.done[key] = Date.now();
  } catch (e) { err('في مثل هذا اليوم', e); }
}

// ───────────── 🏆 جدول الترتيب ─────────────
export async function runStandings(state, fixtures) {
  if (!on('standings') || !env.FOOTBALL_DATA_KEY) return;
  const [from, to] = opt('standings', 'hoursAfter', [2.5, 20]);
  for (const f of fixtures) {
    if (!/primera|la ?liga/i.test(f.competition)) continue;
    const h = (Date.now() - f.kickoff) / 3600000;
    if (h < from || h > to) continue;
    const key = `${f.id}:standings`;
    if (state.done[key]) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < 30 * 60000) continue;
    state.attempts[key] = Date.now();
    try {
      const res = await fetch('https://api.football-data.org/v4/competitions/PD/standings', { headers: { 'X-Auth-Token': env.FOOTBALL_DATA_KEY }, signal: AbortSignal.timeout(20000) });
      if (!res.ok) throw new Error(`football-data ${res.status}`);
      const data = await res.json();
      const table = data.standings?.find((s) => s.type === 'TOTAL')?.table || [];
      if (!table.length) throw new Error('الجدول فاضي');
      const rmIdx = table.findIndex((r) => r.team.id === 86);
      // أول 10، ولو ريال مو منهم نضيف سطره
      const top = opt('standings', 'rows', 10);
      let picked = table.slice(0, top);
      if (rmIdx >= top) picked = [...table.slice(0, top - 1), { ...table[rmIdx], gap: true }];
      const ar = await arabicNames(state, picked.map((r) => r.team.shortName || r.team.name));
      const rows = [];
      for (const r of picked) {
        rows.push({ pos: r.position, name: ar(r.team.shortName || r.team.name), crest: await crestData(r.team.crest),
          played: r.playedGames, won: r.won, draw: r.draw, lost: r.lost, gd: r.goalDifference, pts: r.points, rm: r.team.id === 86, gap: r.gap });
      }
      const png = await renderPng(standingsHtml({ competitionAr: 'الدوري الإسباني', matchday: data.season?.currentMatchday, rows }), { width: 1080, height: 1350 });
      const rm = table[rmIdx], leader = table[0];
      const diff = rm && leader && rm !== leader ? `\nالفارق عن المتصدر ${ar(leader.team.shortName || leader.team.name)}: ${leader.points - rm.points} نقاط` : '';
      const text = `🏆 ترتيب الدوري الإسباني${data.season?.currentMatchday ? ` بعد الجولة ${data.season.currentMatchday}` : ''}\n\nريال مدريد في المركز ${rm?.position} برصيد ${rm?.points} نقطة${rm?.position === 1 ? ' 👑' : ''}${diff}${TAG}`;
      await postImage(text, png, 'جدول ترتيب الدوري الإسباني', `standings-${f.id}.png`);
      state.done[key] = Date.now();
    } catch (e) { err('جدول الترتيب', e); }
  }
}

// ───────────── 🩺 الغيابات قبل المباراة ─────────────
export async function runAbsences(state, fixtures) {
  if (!on('absences')) return;
  const [early, late] = opt('absences', 'hoursBefore', [26, 3]);
  for (const f of fixtures) {
    const h = (f.kickoff - Date.now()) / 3600000;
    if (h > early || h < late) continue;
    const key = `${f.id}:absences`;
    if (state.done[key]) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < 90 * 60000) continue;
    state.attempts[key] = Date.now();
    try {
      const j = parseJson(await askClaude(`ابحث في الإنترنت عن غيابات ريال مدريد (الإصابات والإيقافات والأمراض) قبل مباراته القادمة ضد ${f.opponent.fullName} (${f.competition}) يوم ${new Date(f.kickoff).toISOString().slice(0, 10)}.
اعتمد على أحدث المعلومات من مصادر موثوقة (الموقع الرسمي لريال مدريد، قائمة المباراة الرسمية، صحف كبرى). لا تذكر لاعباً إلا إذا كان غيابه مؤكداً لهذه المباراة.
إذا ما في معلومات كافية بعد أرجع {"found": false}.

أرجع JSON فقط:
{"found":true,"players":[{"name":"الاسم بالعربي","type":"injury|suspension|illness|other","reason":"سبب مختصر بالعربي (مثل: إصابة في العضلة الخلفية)","ret":"موعد العودة المتوقع إن وجد، مختصر"}],"none":false,"competitionAr":"","opponentAr":""}
إذا تأكدت أنه لا يوجد أي غياب، أرجع {"found":true,"none":true,"players":[]}`, { webSearch: true, maxSearches: 5, maxTokens: 2000 }));
      if (!j.found) { console.log('⏳ الغيابات: المعلومات لسه مو كافية'); continue; }
      const opp = j.opponentAr || f.opponent.name;
      const matchLine = f.isHome ? `ريال مدريد × ${opp}` : `${opp} × ريال مدريد`;
      if (j.none || !j.players?.length) {
        await postText(`✅ لا غيابات في صفوف ريال مدريد قبل مواجهة ${opp}\n\nالقائمة مكتملة 💪${TAG}`);
      } else {
        const players = j.players.slice(0, 8);
        const png = await renderPng(absencesHtml({ matchLine, competitionAr: j.competitionAr || f.competition, kickoff: f.kickoff, players }), { width: 1080, height: 1350 });
        const names = players.map((p) => p.name).join('، ');
        let text = `🩺 غيابات ريال مدريد أمام ${opp}\n\n${names}${TAG}`;
        if (!fitsTweet(text)) text = `🩺 غيابات ريال مدريد أمام ${opp} (${players.length} لاعبين)${TAG}`;
        await postImage(text, png, `غيابات ريال مدريد: ${names}`, `absences-${f.id}.png`);
      }
      state.done[key] = Date.now();
    } catch (e) { err('الغيابات', e); }
  }
}

// ───────────── 📈 الأرقام القياسية (قبل وبعد المباراة) ─────────────
export async function runMilestones(state, fixtures) {
  if (!on('milestones')) return;
  for (const f of fixtures) {
    const h = (Date.now() - f.kickoff) / 3600000;
    const phase = h >= -8 && h <= -2 ? 'pre' : h >= 2 && h <= 14 ? 'post' : null;
    if (!phase) continue;
    const key = `${f.id}:milestones:${phase}`;
    if (state.done[key]) continue;
    if (state.attempts[key] && Date.now() - state.attempts[key] < 60 * 60000) continue;
    state.attempts[key] = Date.now();
    const ask = phase === 'pre'
      ? `ابحث عن أرقام قياسية أو محطات مهمة يقترب منها ريال مدريد أو أحد لاعبيه قبل مباراة اليوم ضد ${f.opponent.fullName} (${f.competition})، مثل: "على بعد هدف من هدفه رقم 50"، "قد يصبح أكثر لاعب..."، "يخوض مباراته رقم 300".`
      : `ابحث عن أرقام قياسية أو محطات مهمة حققها ريال مدريد أو أحد لاعبيه في مباراته ضد ${f.opponent.fullName} (${f.competition}) يوم ${new Date(f.kickoff).toISOString().slice(0, 10)}، مثل: "وصل لهدفه رقم 50"، "أصبح أكثر لاعب..."، "سلسلة 10 انتصارات متتالية".`;
    try {
      const j = parseJson(await askClaude(`${ask}
فقط الأرقام المذكورة صراحة في مصادر موثوقة (Opta، الموقع الرسمي، صحف كبرى). لا تحسب الأرقام بنفسك ولا تخمّن.
حتى ${opt('milestones', 'max', 2)} أرقام، الأهم أولاً. إذا لم تجد شيئاً مؤكداً أرجع {"found": false}.
أرجع JSON فقط: {"found":true,"items":[{"tweet":"تغريدة تبدأ بـ ${phase === 'pre' ? '📈' : '🏅'} (حتى 230 حرفاً)","source":"اسم المصدر"}]}`, { webSearch: true, maxSearches: 4, maxTokens: 1500 }));
      if (j.found) {
        for (const it of (j.items || []).slice(0, opt('milestones', 'max', 2))) {
          const text = `${it.tweet.trim()}${it.source ? `\n\nالمصدر: ${it.source}` : ''}${TAG}`;
          if (fitsTweet(text)) await postText(text);
        }
      } else console.log(`⏳ أرقام قياسية (${phase === 'pre' ? 'قبل' : 'بعد'}): لا شيء مؤكد`);
      state.done[key] = Date.now(); // محاولة وحدة تكفي لكل مرحلة
    } catch (e) { err('الأرقام القياسية', e); }
  }
}

// ───────────── 🔁 ملخص الأسبوع ─────────────
export async function runWeekly(state) {
  if (!on('weekly')) return;
  const key = dailyDue(state, 'weekly', opt('weekly', 'hour', 14), 90, opt('weekly', 'weekday', 1));
  if (!key) return;
  const recent = (state.tweets || []).slice(-40).map((t) => `- ${t}`).join('\n');
  try {
    const j = parseJson(await askClaude(`اكتب ملخصاً لأسبوع ريال مدريد (آخر 7 أيام حتى اليوم ${new Date().toISOString().slice(0, 10)}).
ابحث في الإنترنت عن: نتائج مباريات الفريق الأول هذا الأسبوع والهدافين، وأهم الأخبار المؤكدة (إصابات، عودة لاعبين، تصريحات مهمة، قرارات النادي)، والمباراة القادمة وموعدها.
هذه أخبار نشرناها هذا الأسبوع وقد تساعدك:
${recent || '- لا يوجد'}

اكتب سلسلة من 5 إلى 7 تغريدات بالعربية:
- الأولى: "🔁 ملخص أسبوع ريال مدريد" مع جملة تشويقية و #ريال_مدريد و 🧵👇
- بعدها تغريدة لكل محور (النتائج، الأخبار، الغيابات، المباراة القادمة...)، كل وحدة تبدأ برقمها مثل (2/6) وحتى 260 حرفاً.
- معلومات مؤكدة فقط.
أرجع JSON فقط: {"subtitle":"سطر قصير يلخص الأسبوع (حتى 10 كلمات)","tweets":["..."]}`, { webSearch: true, maxSearches: 6, maxTokens: 4000 }));
    const tweets = (j.tweets || []).map((t) => String(t).trim()).filter(fitsTweet);
    if (tweets.length < 3) throw new Error('الملخص قصير');
    let png = null;
    try {
      png = await renderPng(topicHtml({ title: 'ملخص الأسبوع', subtitle: j.subtitle || '', crest: await crestData(RM_CREST()), tag: '🔁 أسبوع ريال مدريد' }), { width: 1200, height: 675 });
    } catch (e) { console.warn('⚠️ غلاف الملخص:', e.message); }
    await postThreadWithImage(tweets, png, 'ملخص أسبوع ريال مدريد');
    state.done[key] = Date.now();
  } catch (e) { err('ملخص الأسبوع', e); }
}
