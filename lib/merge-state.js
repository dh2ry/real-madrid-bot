// يدمج ملف الحالة من تشغيلين مختلفين بدل ما يتعارضون
// الاستخدام: node lib/merge-state.js <ملف المستودع> <ملف هذا التشغيل>  → يكتب الناتج في الملف الأول
import fs from 'node:fs';

const [, , remoteFile, localFile] = process.argv;
const read = (f) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return {}; } };
const isId = (v) => typeof v === 'string' && /^\d{6,}$/.test(v);

// القوائم اللي تنجمع (سجلات). أي قائمة ثانية (مثل النتيجة أو جدول المباريات) نأخذ نسخة هذا التشغيل كما هي
const UNION = new Set(['seen', 'tweets', 'posted', 'otdUsed', 'generic']);

function merge(a, b, key = '') {
  if (b === undefined) return a;
  if (a === undefined) return b;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (!UNION.has(key)) return b;
    const seen = new Set(a.map((x) => JSON.stringify(x)));
    return [...a, ...b.filter((x) => !seen.has(JSON.stringify(x)))];
  }
  if (a && b && typeof a === 'object' && typeof b === 'object' && !Array.isArray(a) && !Array.isArray(b)) {
    // جدول المباريات: الأحدث يكسب كاملاً
    if (key === 'fixtures') return (b.fetchedAt || 0) >= (a.fetchedAt || 0) ? b : a;
    const out = { ...a };
    for (const k of Object.keys(b)) out[k] = merge(a[k], b[k], k);
    return out;
  }
  if (typeof a === 'number' && typeof b === 'number') return Math.max(a, b);
  if (typeof a === 'boolean' && typeof b === 'boolean') return a || b;
  if (isId(a) && isId(b)) return BigInt(a) > BigInt(b) ? a : b;
  return b;
}

const merged = merge(read(remoteFile), read(localFile));
merged.seen = (merged.seen || []).slice(-6000);
merged.tweets = (merged.tweets || []).slice(-100);
fs.writeFileSync(remoteFile, JSON.stringify(merged, null, 2));
