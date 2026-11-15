// طبقة التخزين الدائم — IndexedDB داخل المتصفح (تبقى البيانات بعد التحديث والإغلاق)
import { SEED_FOODS, SEED_VERSION } from '../data/foods.js';

// ── الواجهة الخلفية للتخزين ──
// 1) داخل Claude: قاعدة بيانات الصفحة في مساحة المستخدم الخاصة data/users/<id>/ (لا يراها غيره،
//    وتتزامن بين أجهزته). 2) خارج Claude: IndexedDB في المتصفح.
const STORES = { foods: 'id', meals: 'id', settings: 'key' };
let backendPromise;

export const storageInfo = { kind: 'none' };

function withTimeout(promise, ms, msg) {
  return Promise.race([promise, new Promise((_, rej) => setTimeout(() => rej(new Error(msg)), ms))]);
}

async function pickBackend() {
  if (window.claude?.use) {
    const [cdb, user] = await Promise.all([window.claude.use('db'), window.claude.use('user')]);
    const id = cdb && user ? await user.id() : null;
    if (cdb && id) {
      storageInfo.kind = 'cloud';
      return cloudBackend(cdb, id);
    }
  }
  storageInfo.kind = 'local';
  return idbBackend();
}

function backend() {
  if (!backendPromise) backendPromise = pickBackend();
  return backendPromise;
}

function cloudBackend(cdb, uid) {
  const base = cdb.doc(`data/users/${uid}/app`);
  const col = (store) => base.collection(store);
  const clone = (v) => JSON.parse(JSON.stringify(v));
  // تنفيذ عدد محدود من الكتابات في وقت واحد
  async function pool(items, fn, size = 6) {
    const queue = [...items];
    const workers = Array.from({ length: Math.min(size, queue.length) }, async () => {
      while (queue.length) await fn(queue.shift());
    });
    await Promise.all(workers);
  }
  // إعادة المحاولة عند الضغط المؤقت فقط (unavailable / resource_exhausted)
  const call = async (fn, tries = 4) => {
    for (let i = 0; ; i++) {
      try {
        return await withTimeout(fn(), 20000, 'تعذر الوصول إلى البيانات. تحقق من الاتصال بالإنترنت.');
      } catch (e) {
        const transient = e?.code === 'unavailable' || e?.code === 'resource_exhausted';
        if (!transient || i >= tries - 1) throw e;
        await new Promise((r) => setTimeout(r, 400 * 2 ** i + Math.random() * 300));
      }
    }
  };
  return {
    async getAll(store) {
      const snap = await call(() => col(store).limit(1000).get());
      return snap.docs.filter((d) => d.exists).map((d) => clone(d.data()));
    },
    async get(store, key) {
      const d = await call(() => col(store).doc(key).get());
      return d.exists ? clone(d.data()) : undefined;
    },
    put: (store, v) => call(() => col(store).doc(String(v[STORES[store]])).set(clone(v))),
    del: (store, key) => call(() => col(store).doc(String(key)).delete()),
    putMany: (store, list) => pool(list, (v) => call(() => col(store).doc(String(v[STORES[store]])).set(clone(v)))),
    async replaceAll(store, list) {
      const keep = new Set(list.map((v) => String(v[STORES[store]])));
      const existing = await this.getAll(store);
      await pool(existing.filter((v) => !keep.has(String(v[STORES[store]]))), (v) => call(() => col(store).doc(String(v[STORES[store]])).delete()));
      await this.putMany(store, list);
    },
  };
}

function idbBackend() {
  let dbp;
  const open = () => dbp || (dbp = new Promise((resolve, reject) => {
    const req = indexedDB.open('carb-calculator', 1);
    req.onupgradeneeded = () => {
      for (const [name, keyPath] of Object.entries(STORES)) {
        if (!req.result.objectStoreNames.contains(name)) req.result.createObjectStore(name, { keyPath });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  }));
  const done = (tx) => new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error);
  });
  const read = async (store, fn) => {
    const db = await open();
    return new Promise((resolve, reject) => {
      const r = fn(db.transaction(store).objectStore(store));
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
    });
  };
  const write = async (store, fn) => {
    const db = await open();
    const tx = db.transaction(store, 'readwrite');
    fn(tx.objectStore(store));
    await done(tx);
  };
  return {
    getAll: (store) => read(store, (os) => os.getAll()),
    get: (store, key) => read(store, (os) => os.get(key)),
    put: (store, v) => write(store, (os) => os.put(v)),
    del: (store, key) => write(store, (os) => os.delete(key)),
    putMany: (store, list) => write(store, (os) => list.forEach((v) => os.put(v))),
    replaceAll: (store, list) => write(store, (os) => { os.clear(); list.forEach((v) => os.put(v)); }),
  };
}

const getAll = async (store) => (await backend()).getAll(store);
const put = async (store, v) => { await (await backend()).put(store, v); return v; };
const del = async (store, key) => (await backend()).del(store, key);
const putMany = async (store, list) => (await backend()).putMany(store, list);
const replaceAll = async (store, list) => (await backend()).replaceAll(store, list);

export async function initStorage() {
  await backend();
  return storageInfo.kind;
}

export function uid() {
  return (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));
}

/** توحيد شكل صنف (للاستيراد والحفظ) */
export function cleanFood(f) {
  const num = (v) => (v === '' || v == null || !Number.isFinite(Number(v)) ? null : Number(v));
  return {
    id: f.id || uid(),
    seedId: f.seedId || null,
    name: String(f.name || '').trim(),
    category: f.category || 'other',
    refQty: num(f.refQty),
    unit: String(f.unit || '').trim(),
    carbs: num(f.carbs),
    altQty: num(f.altQty),
    altUnit: String(f.altUnit || '').trim(),
    note: String(f.note || '').trim(),
    source: String(f.source || '').trim(),
    image: f.image || null,
    updatedAt: f.updatedAt || Date.now(),
  };
}

export const settings = {
  async get(key, fallback) {
    const r = await (await backend()).get('settings', key);
    return r ? r.value : fallback;
  },
  set: (key, value) => put('settings', { key, value }),
  all: () => getAll('settings'),
};

export const foods = {
  all: () => getAll('foods'),
  save: (food) => put('foods', cleanFood({ ...food, updatedAt: Date.now() })),
  remove: (id) => del('foods', id),
  replaceAll: (list) => replaceAll('foods', list.map(cleanFood)),
  putMany: (list) => putMany('foods', list.map(cleanFood)),
};

export const meals = {
  all: () => getAll('meals'),
  save: (meal) => put('meals', meal),
  remove: (id) => del('meals', id),
  replaceAll: (list) => replaceAll('meals', list),
};

/**
 * تعبئة البيانات الأولية: في أول تشغيل تُضاف كل الأصناف،
 * وعند تحديث ملف البيانات تُضاف الأصناف الجديدة فقط (دون الكتابة فوق تعديلات المستخدم
 * ودون إعادة صنف حذفه المستخدم).
 */
export async function ensureSeed() {
  const current = await settings.get('seedVersion', 0);
  if (current >= SEED_VERSION) return;
  const existing = await foods.all();
  const known = new Set(await settings.get('knownSeedIds', []));
  existing.forEach((f) => f.seedId && known.add(f.seedId));
  const toAdd = SEED_FOODS.filter((s) => !known.has(s.seedId));
  await foods.putMany(toAdd.map((s) => ({ ...s, id: s.seedId })));
  toAdd.forEach((s) => known.add(s.seedId));
  await settings.set('knownSeedIds', [...known]);
  await settings.set('seedVersion', SEED_VERSION);
}

/** إعادة الأصناف الأصلية من الجداول (يستبدل قاعدة الأطعمة بالكامل) */
export async function restoreOriginalFoods() {
  await foods.replaceAll(SEED_FOODS.map((s) => ({ ...s, id: s.seedId })));
  await settings.set('knownSeedIds', SEED_FOODS.map((s) => s.seedId));
  await settings.set('seedVersion', SEED_VERSION);
}

export async function requestPersistence() {
  if (storageInfo.kind !== 'local') return;
  try {
    if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist();
  } catch { /* غير مدعوم */ }
}
