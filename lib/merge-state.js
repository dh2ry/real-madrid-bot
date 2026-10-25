// يدمج ملف الحالة من تشغيلين مختلفين بدل ما يتعارضون
import fs from 'node:fs';

const [, , remoteFile, localFile] = process.argv;
const read = (f) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return {}; } };
const isId = (v) => typeof v === 'string' && /^\d{6,}$/.test(v);

function merge(a, b) {
  if (b === undefined) return a;
  if (a === undefined) return b;
  if (Array.isArray(a) && Array.isArray(b)) {
    const seen = new Set(a.map((x) => JSON.stringify(x)));
    return [...a, ...b.filter((x) => !seen.has(JSON.stringify(x)))];
  }
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const out = { ...a };
    for (const k of Object.keys(b)) out[k] = merge(a[k], b[k]);
    return out;
  }
  if (typeof a === 'number' && typeof b === 'number') return Math.max(a, b);
  if (typeof a === 'boolean' && typeof b === 'boolean') return a || b;
  if (isId(a) && isId(b)) return BigInt(a) > BigInt(b) ? a : b;
  return b;
}

const merged = merge(read(remoteFile), read(localFile));
merged.seen = (merged.seen || []).slice(-1500);
merged.tweets = (merged.tweets || []).slice(-50);
fs.writeFileSync(remoteFile, JSON.stringify(merged, null, 2));
