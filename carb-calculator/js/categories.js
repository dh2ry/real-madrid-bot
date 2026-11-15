// التصنيفات الرئيسية — المعرّف ثابت، والاسم والأيقونة للعرض
export const CATEGORIES = [
  { id: 'bread', name: 'الخبز والنشويات', icon: '🍞', color: '#f4e3c3' },
  { id: 'grains', name: 'الأرز والمعكرونة والحبوب', icon: '🍚', color: '#efe9da' },
  { id: 'vegetables', name: 'الخضروات', icon: '🥦', color: '#d8f0dc' },
  { id: 'fruits', name: 'الفواكه', icon: '🍎', color: '#fbdcdc' },
  { id: 'dairy', name: 'الحليب ومشتقاته', icon: '🥛', color: '#e3eef9' },
  { id: 'meat', name: 'اللحوم والأطعمة الجاهزة', icon: '🍗', color: '#f6e0d2' },
  { id: 'sweets', name: 'الحلويات والشوكولاتة', icon: '🍫', color: '#ead9cf' },
  { id: 'biscuits', name: 'البسكويت والمقرمشات', icon: '🍪', color: '#f3e6cf' },
  { id: 'drinks', name: 'العصائر والمشروبات', icon: '🧃', color: '#fde9c9' },
  { id: 'other', name: 'أصناف أخرى', icon: '🍽️', color: '#e6e6ef' },
];

const byId = new Map(CATEGORIES.map((c) => [c.id, c]));

export function getCategory(id) {
  return byId.get(id) || byId.get('other');
}

/** يقبل معرّف التصنيف أو اسمه العربي (للاستيراد) */
export function resolveCategory(v) {
  const s = String(v || '').trim();
  if (byId.has(s)) return s;
  const found = CATEGORIES.find((c) => c.name === s || c.name.includes(s) && s.length > 2);
  return found ? found.id : 'other';
}
