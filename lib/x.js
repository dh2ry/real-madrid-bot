import { TwitterApi } from 'twitter-api-v2';
import { config, env, DRY_RUN, saveOutput } from './config.js';

let client;
export function xClient() { return x(); }
function x() {
  client ??= new TwitterApi({
    appKey: env.X_API_KEY,
    appSecret: env.X_API_SECRET,
    accessToken: env.X_ACCESS_TOKEN,
    accessSecret: env.X_ACCESS_SECRET,
  });
  return client;
}

const link = (id) => `https://x.com/i/status/${id}`;

// ───── 🧮 حد النشر اليومي ─────
// الحساب المجاني في X مسموح له 50 تغريدة في 24 ساعة. نعد كل تغريدة، ونحجز جزء لتغطية المباراة،
// والأخبار والمحتوى العام ما ياخذ من المحجوز. ولو X رفضت بسبب الحد، نوقف النشر ساعة بدل ما نكرر المحاولة.
let B = { state: null, limit: 48, reserve: 0 };
export function setBudget(state, { limit = 48, reserve = 0 } = {}) {
  state.postTimes ??= [];
  B = { state, limit, reserve };
}
function used() {
  if (!B.state) return 0;
  const since = Date.now() - 24 * 3600000;
  B.state.postTimes = (B.state.postTimes || []).filter((t) => t > since);
  return B.state.postTimes.length;
}
export function budgetLeft(low = false) { return (low ? B.limit - B.reserve : B.limit) - used(); }
function check(low) {
  if (DRY_RUN || !B.state) return;
  if ((B.state.xBlockedUntil || 0) > Date.now()) {
    throw Object.assign(new Error(`النشر موقوف مؤقتاً من X (حد النشر) حتى ${new Date(B.state.xBlockedUntil).toISOString()}`), { budget: true });
  }
  const u = used(), cap = low ? B.limit - B.reserve : B.limit;
  if (u >= cap) throw Object.assign(new Error(`وصلنا حد النشر اليومي (${u}/${cap}${low ? ' – الباقي محجوز للمباراة' : ''})`), { budget: true });
}
function counted() { B.state?.postTimes.push(Date.now()); }
async function guard(low, fn) {
  check(low);
  try {
    const r = await fn();
    counted();
    return r;
  } catch (e) {
    const msg = JSON.stringify(e.data || '') + (e.message || '');
    if (B.state && (e.code === 403 || /403/.test(msg)) && /not permitted|daily|limit/i.test(msg)) {
      B.state.xBlockedUntil = Date.now() + 60 * 60000;
      console.warn('⛔ X رفضت النشر (حد النشر اليومي) — بنوقف النشر ساعة ونعيد المحاولة');
    }
    throw e;
  }
}

// سجل مشترك لكل اللي ينشره البوت، عشان الأقسام ما تكرر بعضها (الأخبار، الحساب الرسمي، ملخص الأسبوع…)
let logFn = null;
export function setPostLog(fn) { logFn = fn; }
const log = (t) => { try { logFn?.(String(t).replace(/\n+/g, ' ').slice(0, 220)); } catch { /* */ } };

export async function postText(text, { low = false } = {}) {
  if (DRY_RUN) { console.log(`🧪 تغريدة (لم تُنشر):\n${text}\n`); return; }
  const { data } = await guard(low, () => x().v2.tweet(text));
  console.log(`✅ نُشرت: ${link(data.id)}`);
  log(text);
}

// سلسلة تغريدات، أو منشور طويل وحد لو حسابك موثّق (longPosts)
export async function postThread(tweets, { low = false } = {}) {
  if (config.longPosts) return postText(tweets.join('\n\n'), { low });
  if (DRY_RUN) {
    console.log('🧪 سلسلة (لم تُنشر):\n' + tweets.map((t, i) => `[${i + 1}/${tweets.length}] ${t}`).join('\n—\n') + '\n');
    return;
  }
  const res = await guard(low, () => x().v2.tweetThread(tweets));
  console.log(`✅ نُشرت سلسلة: ${link(res[0].data.id)}`);
  log(tweets[0]);
}

async function uploadPng(buffer) {
  try {
    return await x().v2.uploadMedia(buffer, { media_type: 'image/png' });
  } catch (e) {
    return await x().v1.uploadMedia(buffer, { mimeType: 'image/png' });
  }
}

export async function postImage(text, buffer, altText, fileName = 'image.png', { low = false } = {}) {
  if (DRY_RUN) {
    const p = saveOutput(fileName, buffer);
    console.log(`🧪 صورة (لم تُنشر) محفوظة في ${p}\n${text}\n`);
    return;
  }
  check(low);
  const mediaId = await uploadPng(buffer);
  if (altText) {
    await x().v1.createMediaMetadata(mediaId, { alt_text: { text: altText.slice(0, 1000) } }).catch(() => {});
  }
  const { data } = await guard(low, () => x().v2.tweet(text, { media: { media_ids: [mediaId] } }));
  console.log(`✅ نُشرت الصورة: ${link(data.id)}`);
  log(text);
}

// سلسلة تغريدات، والصورة (إن وجدت) على أول تغريدة
export async function postThreadWithImage(tweets, png, altText, { low = false } = {}) {
  if (DRY_RUN) {
    if (png) console.log(`🧪 صورة الغلاف محفوظة في ${saveOutput('topic-cover.png', png)}`);
    console.log('🧪 سلسلة (لم تُنشر):\n' + tweets.map((t, i) => `[${i + 1}/${tweets.length}] ${t}`).join('\n—\n') + '\n');
    return;
  }
  check(low);
  const items = tweets.map((text) => ({ text }));
  if (png) {
    try {
      const mediaId = await uploadPng(png);
      if (altText) await x().v1.createMediaMetadata(mediaId, { alt_text: { text: altText.slice(0, 1000) } }).catch(() => {});
      items[0].media = { media_ids: [mediaId] };
    } catch (e) { console.warn('⚠️ رفع الصورة:', e.message); }
  }
  const res = await guard(low, () => x().v2.tweetThread(items));
  console.log(`✅ نُشرت السلسلة (${tweets.length} تغريدات): ${link(res[0].data.id)}`);
  log(tweets[0]);
}
