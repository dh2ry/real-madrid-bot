// منطق الحساب — دوال نقية بدون أي اعتماد على الواجهة (قابلة للاختبار)

/** الوحدات التي تُعتبر وزناً/حجماً يُدخل المستخدم قيمته مباشرة */
export const WEIGHT_UNITS = ['جرام', 'مل'];

/** الوحدات المقترحة في النماذج (يمكن كتابة أي وحدة أخرى) */
export const UNIT_SUGGESTIONS = [
  'جرام', 'مل', 'حبة', 'كوب', 'قطعة', 'كيس', 'ملعقة كبيرة', 'ملعقة صغيرة',
  'شريحة', 'علبة', 'صحن', 'رغيف', 'كأس', 'لوح', 'باكيت', 'حصة',
];

export const DEFAULT_RATIO = 25;

export function isWeightUnit(unit) {
  return WEIGHT_UNITS.includes(String(unit || '').trim());
}

/** هل بيانات الصنف مكتملة للحساب؟ (بعض صفوف الجداول ينقصها رقم) */
export function isComplete(food) {
  return !!food && Number(food.refQty) > 0 && food.carbs !== null && food.carbs !== '' && Number(food.carbs) >= 0;
}

/** هل للصنف قياس مكافئ؟ مثال: 1 كوب = 250 مل، 2 حبة = 32 جرام، 10 كبيرة = 15 صغيرة */
export function hasAlt(food) {
  return Number(food?.altQty) > 0 && !!String(food?.altUnit || '').trim();
}

/**
 * يحسب الكربوهيدرات لكمية من صنف.
 * mode = 'unit' → qty بالوحدة المرجعية للصنف (جرام، كوب، حبة...)
 * mode = 'alt'  → qty بالقياس المكافئ (مثلاً بالمل أو بالجرام)
 * المعادلة: الكمية المختارة ÷ الكمية المرجعية × كربوهيدرات المرجع
 */
export function carbsFor(food, qty, mode = 'unit') {
  qty = Number(qty);
  if (!isComplete(food)) return NaN;
  if (!(qty > 0)) return 0;
  const carbs = Number(food.carbs);
  if (mode === 'alt') {
    if (!hasAlt(food)) return NaN;
    return (qty / Number(food.altQty)) * carbs;
  }
  return (qty / Number(food.refQty)) * carbs;
}

export function sumCarbs(values) {
  return values.reduce((s, v) => s + (Number.isFinite(v) ? v : 0), 0);
}

/** تقريب للعرض فقط */
export function roundTo(n, d = 1) {
  const f = 10 ** d;
  return Math.round((n + Number.EPSILON) * f) / f;
}

/** جرعة الإنسولين الحسابية = إجمالي الكربوهيدرات ÷ المعامل (بدون أي تقريب للجرعة) */
export function insulinDose(totalCarbs, ratio) {
  ratio = Number(ratio);
  if (!(ratio > 0)) return NaN;
  return Number(totalCarbs) / ratio;
}

/** عرض الجرعة بمنزلتين عشريتين بالضبط */
export function formatDose(dose) {
  return Number.isFinite(dose) ? dose.toFixed(2) : '—';
}

/** عرض رقم بدون أصفار زائدة (حتى منزلة واحدة افتراضياً) */
export function fmt(n, d = 1) {
  if (!Number.isFinite(n)) return '—';
  return String(roundTo(n, d));
}

/** تحويل الأرقام العربية/الفارسية والفاصلة العربية إلى رقم */
export function parseNum(v) {
  if (typeof v === 'number') return v;
  const s = String(v ?? '')
    .replace(/[٠-٩]/g, (c) => c.charCodeAt(0) - 0x660)
    .replace(/[۰-۹]/g, (c) => c.charCodeAt(0) - 0x6f0)
    .replace(/[٫,]/g, '.')
    .replace(/\s/g, '');
  if (s === '') return NaN;
  // دعم الكسور مثل 1/2
  const frac = s.match(/^(\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)$/);
  if (frac) return Number(frac[1]) / Number(frac[2]);
  return Number(s);
}

/** توحيد النص العربي للبحث */
export function normalizeAr(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[ً-ٰٟـ]/g, '') // تشكيل وتطويل
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim();
}

export function matchesQuery(name, query) {
  const q = normalizeAr(query);
  if (!q) return true;
  const n = normalizeAr(name);
  return q.split(' ').every((w) => n.includes(w));
}

/** عرض الكميات بكسور مألوفة: 0.5 → ½ */
const FRACTIONS = { 0.25: '¼', 0.5: '½', 0.75: '¾', 0.33: '⅓', 0.67: '⅔' };
export function fmtQty(n) {
  n = Number(n);
  if (!Number.isFinite(n)) return '—';
  const whole = Math.floor(n);
  const frac = roundTo(n - whole, 2);
  if (frac === 0) return String(whole);
  if (FRACTIONS[frac]) return whole ? `${whole}${FRACTIONS[frac]}` : FRACTIONS[frac];
  return String(roundTo(n, 2));
}

/** نص يصف الكمية المرجعية للصنف: "1 كوب (250 مل)" */
export function refLabel(food) {
  if (!(Number(food.refQty) > 0)) return 'الكمية غير محددة';
  let s = `${fmtQty(food.refQty)} ${food.unit}`;
  if (hasAlt(food)) s += ` (${fmtQty(food.altQty)} ${food.altUnit})`;
  return s;
}

/** نص الكمية المختارة لعنصر في الوجبة */
export function qtyLabel(item, food) {
  const unit = item.mode === 'alt' ? food.altUnit : food.unit;
  return `${fmtQty(item.qty)} ${unit}`;
}

/** التحقق من بيانات صنف قبل الحفظ؛ يُرجع قائمة أخطاء */
export function validateFood(f) {
  const errors = [];
  if (!String(f.name || '').trim()) errors.push('اسم الصنف مطلوب');
  if (!String(f.category || '').trim()) errors.push('التصنيف مطلوب');
  if (!(Number(f.refQty) > 0)) errors.push('الكمية المرجعية يجب أن تكون أكبر من صفر');
  if (!String(f.unit || '').trim()) errors.push('نوع الوحدة مطلوب');
  if (!(Number(f.carbs) >= 0) || f.carbs === '' || f.carbs == null) errors.push('كمية الكربوهيدرات مطلوبة (صفر أو أكثر)');
  const hasAltQty = f.altQty !== '' && f.altQty != null;
  if (hasAltQty && !(Number(f.altQty) > 0)) errors.push('القياس المكافئ يجب أن يكون أكبر من صفر أو يُترك فارغاً');
  if (hasAltQty && !String(f.altUnit || '').trim()) errors.push('حدد وحدة القياس المكافئ');
  return errors;
}
