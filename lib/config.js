import fs from 'node:fs';

export const ROOT = new URL('../', import.meta.url);
export const config = JSON.parse(fs.readFileSync(new URL('config.json', ROOT)));
export const env = process.env;
export const DRY_RUN = env.DRY_RUN === 'true';

const STATE_FILE = new URL('state/posted.json', ROOT);

export function loadState() {
  let s;
  try { s = JSON.parse(fs.readFileSync(STATE_FILE)); } catch { s = {}; }
  return { seen: [], tweets: [], done: {}, attempts: {}, afIds: {}, ...s };
}

export function saveState(state) {
  state.seen = state.seen.slice(-6000);
  state.tweets = state.tweets.slice(-100);
  for (const [id, L] of Object.entries(state.live || {})) {
    L.ts ??= Date.now();
    if (L.ts < Date.now() - 21 * 86400000) delete state.live[id];
  }
  // تنظيف السجلات الأقدم من 21 يوم
  const cutoff = Date.now() - 21 * 86400000;
  for (const bag of [state.done, state.attempts]) {
    for (const [k, t] of Object.entries(bag)) if (t < cutoff) delete bag[k];
  }
  fs.mkdirSync(new URL('state/', ROOT), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

export function saveOutput(name, data) {
  const dir = new URL('out/', ROOT);
  fs.mkdirSync(dir, { recursive: true });
  const file = new URL(name, dir);
  fs.writeFileSync(file, data);
  return file.pathname;
}

export const fmtTime = (ts) => new Intl.DateTimeFormat('ar-u-nu-latn', {
  timeZone: config.timezone || 'Asia/Riyadh', hour: 'numeric', minute: '2-digit', hour12: true,
}).format(ts);

export const fmtDate = (ts) => new Intl.DateTimeFormat('ar-u-nu-latn', {
  timeZone: config.timezone || 'Asia/Riyadh', weekday: 'long', day: 'numeric', month: 'long',
}).format(ts);

// الوقت المحلي (حسب timezone في الإعدادات): الساعة، اليوم (0=الأحد)، التاريخ
export function localNow() {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {
    timeZone: config.timezone || 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', hourCycle: 'h23', weekday: 'short',
  }).formatToParts(new Date()).map((x) => [x.type, x.value]));
  const wd = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }[p.weekday];
  return { hour: Number(p.hour), weekday: wd, ymd: `${p.year}-${p.month}-${p.day}`, month: Number(p.month), day: Number(p.day) };
}

// مهمة يومية: تشتغل مرة وحدة باليوم بعد ساعة معيّنة، وتعيد المحاولة كل retryMin لو فشلت
export function dailyDue(state, name, hour, retryMin = 60, weekday = null) {
  const n = localNow();
  if (n.hour < hour || (weekday != null && n.weekday !== weekday)) return null;
  const key = `${name}:${n.ymd}`;
  if (state.done[key]) return null;
  if (state.attempts[key] && Date.now() - state.attempts[key] < retryMin * 60000) return null;
  state.attempts[key] = Date.now();
  return key;
}
