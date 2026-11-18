// محاكاة مبسطة لـ window.claude (db + user + downloads) لاختبار مسار الحفظ في الحساب.
// تحفظ المستندات في localStorage لتبقى بعد إعادة التحميل.
(() => {
  const KEY = '__mock_db__';
  const load = () => JSON.parse(localStorage.getItem(KEY) || '{}');
  const save = (m) => localStorage.setItem(KEY, JSON.stringify(m));
  const segs = (p) => p.split('/').length;
  const wait = () => new Promise((r) => setTimeout(r, 2));
  window.__mockWrites = 0;
  const docRef = (path) => {
    if (segs(path) % 2) throw new TypeError('document path must have even segments: ' + path);
    return {
      id: path.split('/').pop(), path,
      async get() { await wait(); const d = load()[path]; return { id: this.id, exists: !!d, data: () => d && Object.freeze(JSON.parse(JSON.stringify(d))), metadata: {} }; },
      async set(v) { await wait(); window.__mockWrites++; const m = load(); m[path] = JSON.parse(JSON.stringify(v)); save(m); },
      async update(v) { const m = load(); if (!m[path]) throw { code: 'invalid_argument' }; Object.assign(m[path], v); save(m); },
      async delete() { await wait(); const m = load(); delete m[path]; save(m); },
      collection: (c) => colRef(path + '/' + c),
    };
  };
  const colRef = (path, filters = []) => {
    if (segs(path) % 2 === 0) throw new TypeError('collection path must have odd segments: ' + path);
    return {
      path,
      doc: (id) => docRef(path + '/' + (id || Math.random().toString(36).slice(2))),
      limit: () => colRef(path, filters),
      where: (field, op, value) => {
        if (op !== '==') throw new Error('mock supports == only');
        return colRef(path, [...filters, (d) => d[field] === value]);
      },
      async get() {
        await wait();
        const m = load();
        const docs = Object.keys(m).filter((k) => k.startsWith(path + '/') && segs(k) === segs(path) + 1)
          .filter((k) => filters.every((f) => f(m[k])))
          .sort().map((k) => ({ id: k.split('/').pop(), exists: true, data: () => JSON.parse(JSON.stringify(m[k])), metadata: {} }));
        return { docs, size: docs.length, empty: !docs.length };
      },
    };
  };
  const caps = {
    db: { doc: docRef, collection: colRef },
    user: { id: async () => 'viewer-123', isOwner: () => true },
    downloads: { save: async ({ filename }) => { window.__lastDownload = filename; return { status: 'saved' }; } },
  };
  window.claude = { use: async (n) => caps[n] || null };
})();
