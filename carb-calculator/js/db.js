// طبقة التخزين الدائم — IndexedDB داخل المتصفح (تبقى البيانات بعد التحديث والإغلاق)
import { SEED_FOODS, SEED_VERSION } from '../data/foods.js';

const DB_NAME = 'carb-calculator';
const DB_VERSION = 1;
let dbPromise;

function open() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('foods')) db.createObjectStore('foods', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('meals')) db.createObjectStore('meals', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('settings')) db.createObjectStore('settings', { keyPath: 'key' });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

function done(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error);
  });
}

async function getAll(store) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const r = db.transaction(store).objectStore(store).getAll();
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}

async function put(store, value) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  tx.objectStore(store).put(value);
  await done(tx);
  return value;
}

async function del(store, key) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  tx.objectStore(store).delete(key);
  await done(tx);
}

async function replaceAll(store, values) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  const os = tx.objectStore(store);
  os.clear();
  values.forEach((v) => os.put(v));
  await done(tx);
}

async function putMany(store, values) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  const os = tx.objectStore(store);
  values.forEach((v) => os.put(v));
  await done(tx);
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
    const db = await open();
    return new Promise((resolve, reject) => {
      const r = db.transaction('settings').objectStore('settings').get(key);
      r.onsuccess = () => resolve(r.result ? r.result.value : fallback);
      r.onerror = () => reject(r.error);
    });
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
  try {
    if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist();
  } catch { /* غير مدعوم */ }
}
