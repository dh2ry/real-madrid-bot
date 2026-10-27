// بوت ريال مدريد: أخبار + تشكيلة مصممة + مؤتمرات صحفية مترجمة ← حسابك في X
import { DRY_RUN, loadState, saveState, saveOutput } from './lib/config.js';
import { setPostLog } from './lib/x.js';
import { runNews } from './lib/news.js';
import { getFixtures } from './lib/fixtures.js';
import { runLineup, buildLineupPost } from './lib/lineup.js';
import { runPressers } from './lib/pressers.js';
import { shouldGoLive, runLive } from './lib/live.js';
import { SAMPLE_FIXTURE, SAMPLE_LINEUP } from './lib/sample.js';
import { runTopic } from './lib/topic.js';
import { runMotm } from './lib/motm.js';
import { runOfficialX } from './lib/officialx.js';
import { runCovers } from './lib/covers.js';
import { runOnThisDay, runStandings, runAbsences, runMilestones, runWeekly } from './lib/extras.js';

// كل قسم له وقت أقصى، عشان لو علق طلب ما يوقف البوت كله
async function step(name, fn, minutes = 8) {
  let timer;
  const limit = new Promise((_, rej) => { timer = setTimeout(() => rej(new Error(`تجاوز ${minutes} دقائق وتم تخطيه`)), minutes * 60000); });
  try { await Promise.race([fn(), limit]); } catch (e) { console.error(`❌ ${name}:`, e.message); } finally { clearTimeout(timer); }
}

async function main() {
  // معاينة تصميم التشكيلة بدون نشر: node bot.js --preview-card
  if (process.argv.includes('--preview-card')) {
    const next = (await getFixtures(loadState())).find((f) => f.kickoff > Date.now());
    const f = next || SAMPLE_FIXTURE;
    const { png, text } = await buildLineupPost(f, { ...SAMPLE_LINEUP, opponentAr: next?.opponent.name || SAMPLE_LINEUP.opponentAr });
    console.log(`🖼️ معاينة محفوظة في ${saveOutput('lineup-preview.png', png)}\n${text}`);
    return;
  }

  // 🧵 سلسلة عن موضوع تكتبه في خانة «الموضوع» عند Run workflow
  const topic = (process.env.TOPIC || '').trim();
  if (topic) { await step('سلسلة الموضوع', () => runTopic(topic), 15); return; }

  const state = loadState();
  setPostLog((t) => state.tweets.push(t));
  let fixtures = [];
  await step('جدول المباريات', async () => { fixtures = await getFixtures(state); }, 2);
  await step('التشكيلة', () => runLineup(state, fixtures));
  await step('المؤتمرات', () => runPressers(state, fixtures), 20);
  await step('الأخبار', () => runNews(state), 10);
  await step('الحساب الرسمي', () => runOfficialX(state));
  await step('أغلفة الصحف', () => runCovers(state));
  await step('أفضل لاعب', () => runMotm(state, fixtures));
  await step('الغيابات', () => runAbsences(state, fixtures));
  await step('الأرقام القياسية', () => runMilestones(state, fixtures));
  await step('جدول الترتيب', () => runStandings(state, fixtures));
  await step('في مثل هذا اليوم', () => runOnThisDay(state));
  await step('ملخص الأسبوع', () => runWeekly(state));
  if (!DRY_RUN) saveState(state);

  // 🔴 وضع المباراة المباشر: يفحص الأحداث كل دقيقة لين النهاية
  const live = fixtures.find((f) => shouldGoLive(f, state));
  if (live) {
    await runLive(state, live, async () => {
      if (Date.now() < live.kickoff) await step('التشكيلة', () => runLineup(state, fixtures));
      await step('الأخبار', () => runNews(state));
      await step('الحساب الرسمي', () => runOfficialX(state, { liveNow: Date.now() > live.kickoff }));
      if (!DRY_RUN) saveState(state);
    });
    if (!DRY_RUN) saveState(state);
  }
}

// نخرج بشكل صريح عشان أي طلب معلّق بالخلفية ما يخلي التشغيل واقف
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
