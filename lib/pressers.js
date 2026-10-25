// المؤتمرات الصحفية: قبل المباراة بيوم وبعدها، لريال مدريد والفريق المنافس
import { config } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { postThread } from './x.js';

async function findPresser(f, phase, club) {
  const home = f.isHome ? 'Real Madrid' : f.opponent.fullName;
  const away = f.isHome ? f.opponent.fullName : 'Real Madrid';
  const team = club === 'rm' ? 'Real Madrid' : f.opponent.fullName;
  const max = config.pressers?.maxQuotes ?? 6;
  const when = phase === 'pre'
    ? 'المؤتمر الصحفي الذي يسبق المباراة (يُعقد عادة قبلها بيوم)'
    : 'المؤتمر الصحفي بعد نهاية المباراة';

  const prompt = `ابحث في الإنترنت عن ${when} لمدرب ${team}، الخاص بمباراة ${home} ضد ${away} (${f.competition}) التي بدأت/تبدأ ${new Date(f.kickoff).toISOString()} بتوقيت UTC.

قواعد البحث:
- ابحث بالإنجليزية والإسبانية ولغة النادي المنافس إن لزم (مثل "press conference" و"rueda de prensa") مع اسم المدرب.
- لازم يكون المؤتمر قد عُقد فعلاً ومرتبطاً بهذه المباراة تحديداً. لا تستخدم مؤتمرات مباريات سابقة.
- إذا لم تجد تغطية واضحة وموثوقة لهذا المؤتمر، أرجع {"found": false}.

إذا وجدته، اكتب سلسلة تغريدات بالعربية:
1. التغريدة الأولى عنوان: "🎙️ أبرز تصريحات [اسم المدرب بالعربي] مدرب [الفريق بالعربي] ${phase === 'pre' ? 'قبل' : 'بعد'} مواجهة [المنافس بالعربي]"${phase === 'post' ? ' مع ذكر نتيجة المباراة' : ''}، وأضف #ريال_مدريد.
2. بعدها من 3 إلى ${max} تغريدات، كل وحدة تصريح واحد مهم مترجم بأمانة للعربية الفصحى المبسطة بين « ».
- كل تغريدة لا تتجاوز 260 حرفاً.
- ترجم المعنى بدقة. لا تضف أي تصريح غير موجود في المصادر، ولا تخلط تصريحات اللاعبين بتصريحات المدرب.
- ركّز على: الإصابات والغيابات، التشكيلة، الخصم، الحالة الفنية، والتصريحات اللافتة.

أرجع JSON فقط:
{"found":true,"coach":"Name","sources":["URL"],"tweets":["...","..."]}`;

  const j = parseJson(await askClaude(prompt, { webSearch: true, maxSearches: 5, maxTokens: 3000 }));
  if (!j.found) return null;
  const tweets = (j.tweets || []).filter(fitsTweet).map((t) => t.trim());
  if (tweets.length < 2) return null;
  return { ...j, tweets };
}

export async function runPressers(state, fixtures) {
  if (config.pressers?.enabled === false) return;
  const [preFrom, preTo] = config.pressers?.preHoursBefore ?? [30, 2];
  const [postFrom, postTo] = config.pressers?.postHoursAfter ?? [1.75, 10];
  const retry = (config.pressers?.retryMinutes ?? 60) * 60000;
  const clubs = config.pressers?.opponent === false ? ['rm'] : ['rm', 'opp'];

  for (const f of fixtures) {
    const h = (Date.now() - f.kickoff) / 3600000; // سالب = قبل المباراة
    const phases = [];
    if (h >= -preFrom && h <= -preTo) phases.push('pre');
    if (h >= postFrom && h <= postTo) phases.push('post');

    for (const phase of phases) {
      for (const club of clubs) {
        const key = `${f.id}:${phase}:${club}`;
        if (state.done[key]) continue;
        if (state.attempts[key] && Date.now() - state.attempts[key] < retry) continue;
        state.attempts[key] = Date.now();

        const label = `${phase === 'pre' ? 'قبل' : 'بعد'} المباراة – ${club === 'rm' ? 'ريال مدريد' : f.opponent.name}`;
        try {
          const r = await findPresser(f, phase, club);
          if (!r) { console.log(`⏳ مؤتمر ${label}: لم يُعثر عليه بعد`); continue; }
          console.log(`🎙️ مؤتمر ${label} (${r.sources?.[0] || ''})`);
          await postThread(r.tweets);
          state.done[key] = Date.now();
        } catch (e) {
          console.error(`❌ مؤتمر ${label}:`, e.data ? JSON.stringify(e.data) : e.message);
        }
      }
    }
  }
}
