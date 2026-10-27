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

// سجل مشترك لكل اللي ينشره البوت، عشان الأقسام ما تكرر بعضها (الأخبار، الحساب الرسمي، ملخص الأسبوع…)
let logFn = null;
export function setPostLog(fn) { logFn = fn; }
const log = (t) => { try { logFn?.(String(t).replace(/\n+/g, ' ').slice(0, 220)); } catch { /* */ } };

export async function postText(text) {
  if (DRY_RUN) { console.log(`🧪 تغريدة (لم تُنشر):\n${text}\n`); return; }
  const { data } = await x().v2.tweet(text);
  console.log(`✅ نُشرت: ${link(data.id)}`);
  log(text);
}

// سلسلة تغريدات، أو منشور طويل وحد لو حسابك موثّق (longPosts)
export async function postThread(tweets) {
  if (config.longPosts) return postText(tweets.join('\n\n'));
  if (DRY_RUN) {
    console.log('🧪 سلسلة (لم تُنشر):\n' + tweets.map((t, i) => `[${i + 1}/${tweets.length}] ${t}`).join('\n—\n') + '\n');
    return;
  }
  const res = await x().v2.tweetThread(tweets);
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

export async function postImage(text, buffer, altText, fileName = 'image.png') {
  if (DRY_RUN) {
    const p = saveOutput(fileName, buffer);
    console.log(`🧪 صورة (لم تُنشر) محفوظة في ${p}\n${text}\n`);
    return;
  }
  const mediaId = await uploadPng(buffer);
  if (altText) {
    await x().v1.createMediaMetadata(mediaId, { alt_text: { text: altText.slice(0, 1000) } }).catch(() => {});
  }
  const { data } = await x().v2.tweet(text, { media: { media_ids: [mediaId] } });
  console.log(`✅ نُشرت الصورة: ${link(data.id)}`);
  log(text);
}

// سلسلة تغريدات، والصورة (إن وجدت) على أول تغريدة
export async function postThreadWithImage(tweets, png, altText) {
  if (DRY_RUN) {
    if (png) console.log(`🧪 صورة الغلاف محفوظة في ${saveOutput('topic-cover.png', png)}`);
    console.log('🧪 سلسلة (لم تُنشر):\n' + tweets.map((t, i) => `[${i + 1}/${tweets.length}] ${t}`).join('\n—\n') + '\n');
    return;
  }
  const items = tweets.map((text) => ({ text }));
  if (png) {
    try {
      const mediaId = await uploadPng(png);
      if (altText) await x().v1.createMediaMetadata(mediaId, { alt_text: { text: altText.slice(0, 1000) } }).catch(() => {});
      items[0].media = { media_ids: [mediaId] };
    } catch (e) { console.warn('⚠️ رفع الصورة:', e.message); }
  }
  const res = await x().v2.tweetThread(items);
  console.log(`✅ نُشرت السلسلة (${tweets.length} تغريدات): ${link(res[0].data.id)}`);
  log(tweets[0]);
}
