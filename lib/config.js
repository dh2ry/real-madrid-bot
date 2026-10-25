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
  state.seen = state.seen.slice(-1500);
  state.tweets = state.tweets.slice(-50);
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
