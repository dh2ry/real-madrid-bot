// سلسلة تغريدات عن موضوع تختاره (تاريخ، أساطير، مواسم...) مع صورة غلاف مصممة
import { config, env } from './config.js';
import { askClaude, parseJson, fitsTweet } from './claude.js';
import { topicHtml, renderPng, crestData } from './card.js';
import { postThreadWithImage } from './x.js';

export async function runTopic(topic) {
  const count = Math.min(Math.max(Number(env.TOPIC_TWEETS) || 8, 3), 15);
  console.log(`🧵 موضوع: ${topic} (${count} تغريدات)`);

  const prompt = `أنت كاتب محتوى رياضي لحساب عربي عن ريال مدريد على منصة X.

الموضوع المطلوب: «${topic}»

ابحث في الإنترنت عن معلومات موثوقة عن هذا الموضوع (مصادر مثل الموقع الرسمي لريال مدريد، UEFA، Wikipedia، والصحف الرياضية الكبرى)، ثم اكتب سلسلة من ${count} تغريدات بالعربية الفصحى المبسطة.

قواعد الكتابة:
- أسلوب قصصي ممتع يشد القارئ، مع معلومات دقيقة: أسماء، تواريخ، نتائج، أرقام.
- التغريدة الأولى افتتاحية مشوقة تنتهي بـ 🧵👇 وفيها #ريال_مدريد.
- كل تغريدة تبدأ برقمها مثل (2/${count}) وتحتوي فكرة واحدة واضحة، ولا تتجاوز 260 حرفاً.
- التغريدة الأخيرة خاتمة قوية وفيها #ريال_مدريد.
- استخدم إيموجي باعتدال (واحد أو اثنين في التغريدة كحد أقصى).
- لا تخترع أي معلومة أو اقتباس. إذا لم تتأكد من رقم أو تاريخ، لا تذكره.

واكتب أيضاً عنواناً قصيراً للصورة (3 إلى 6 كلمات) وسطراً فرعياً قصيراً (حتى 10 كلمات).

أرجع JSON فقط:
{"title":"...","subtitle":"...","tweets":["...","..."],"sources":["URL"]}`;

  const j = parseJson(await askClaude(prompt, { webSearch: true, maxSearches: 8, maxTokens: 6000 }));
  const tweets = (j.tweets || []).map((t) => String(t).trim()).filter(Boolean);
  const bad = tweets.filter((t) => !fitsTweet(t));
  if (bad.length) console.warn(`⚠️ ${bad.length} تغريدة أطول من المسموح وتم حذفها`);
  const ok = tweets.filter(fitsTweet);
  if (ok.length < 3) throw new Error('السلسلة قصيرة جداً، جرّب موضوعاً أوضح');
  if (j.sources?.length) console.log('📚 المصادر:\n' + j.sources.map((s) => '  ' + s).join('\n'));

  let png = null;
  try {
    const crest = await crestData((config.crests || {})['Real Madrid'] || 'https://crests.football-data.org/86.png');
    png = await renderPng(topicHtml({ title: j.title || topic, subtitle: j.subtitle || '', crest }), { width: 1200, height: 675 });
  } catch (e) { console.warn('⚠️ صورة الغلاف:', e.message); }

  await postThreadWithImage(ok, png, j.title || topic);
}
