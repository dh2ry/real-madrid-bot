// تشغيل: node --test carb-calculator/tests
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  carbsFor, insulinDose, formatDose, parseNum, normalizeAr, matchesQuery, sumCarbs, roundTo,
  isComplete, hasAlt, validateFood, refLabel, fmtQty,
  weekdayName, formatTime12, dueTime, todayStr, isValidDateStr, logsToCSV,
} from '../js/calc.js';
import { SEED_FOODS } from '../data/foods.js';
import { CATEGORIES } from '../js/categories.js';

const close = (a, b) => assert.ok(Math.abs(a - b) < 1e-9, `${a} ≠ ${b}`);
const seed = (id) => SEED_FOODS.find((f) => f.seedId === id);

test('مثال الأرز بالجرام: 150 ÷ 100 × 30 = 45', () => {
  const rice = { refQty: 100, unit: 'جرام', carbs: 30 };
  close(carbsFor(rice, 150), 45);
});

test('الأصناف المعدودة تُحسب حسب الكمية المرجعية', () => {
  close(carbsFor(seed('s001'), 4), 15); // بسكوت ماري: 4 حبات = 15
  close(carbsFor(seed('s001'), 2), 7.5);
  close(carbsFor(seed('s033'), 1), 60); // خبز إيراني: ¼ حبة = 15 → حبة كاملة 60
  close(carbsFor(seed('s039'), 1), 45); // سباغيتي: ⅓ كوب = 15 → كوب 45
  close(carbsFor(seed('s105'), 9), 30); // ناغتس: 4½ = 15
  close(carbsFor(seed('s101'), 12), 100); // صب وي 6 إنش = 50
});

test('القياس المكافئ: مل وجرام وحبات صغيرة', () => {
  close(carbsFor(seed('s008'), 250, 'alt'), 12); // حليب 250 مل
  close(carbsFor(seed('s008'), 125, 'alt'), 6);
  close(carbsFor(seed('s012'), 250, 'alt'), 24); // حليب شوكولاتة ½ كوب (125 مل) = 12
  close(carbsFor(seed('s012'), 1), 24);
  close(carbsFor(seed('s019'), 15, 'alt'), 15); // عنب 15 حبة صغيرة
  close(carbsFor(seed('s082'), 16, 'alt'), 7.5); // كب كيك 32 جم = 15
  assert.ok(Number.isNaN(carbsFor(seed('s001'), 10, 'alt')), 'لا يوجد قياس مكافئ');
});

test('الأصناف الناقصة لا تُحسب ولا تُخترع لها قيمة', () => {
  for (const id of ['s021', 's025', 's026']) {
    assert.equal(isComplete(seed(id)), false, id);
    assert.ok(Number.isNaN(carbsFor(seed(id), 1)), id);
  }
});

test('مثال الوجبة والإنسولين: 87 ÷ 25 = 3.48', () => {
  const total = sumCarbs([30, 45, 12]);
  assert.equal(total, 87);
  assert.equal(formatDose(insulinDose(total, 25)), '3.48');
});

test('الجرعة بمنزلتين دون تقريب إضافي', () => {
  assert.equal(formatDose(insulinDose(10, 25)), '0.40');
  assert.equal(formatDose(insulinDose(100, 25)), '4.00');
  assert.equal(formatDose(insulinDose(62.5, 25)), '2.50');
  assert.equal(formatDose(insulinDose(50, 0)), '—');
});

test('وجبة حقيقية من الجداول', () => {
  // خبز لبناني ثقيل (45) + كوب أرز (45) + كوب حليب (12) + حبة تفاح (15) = 117
  const total = sumCarbs([
    carbsFor(seed('s028'), 1), carbsFor(seed('s037'), 1), carbsFor(seed('s008'), 1), carbsFor(seed('s013'), 1),
  ]);
  close(total, 117);
  assert.equal(formatDose(insulinDose(total, 25)), '4.68');
});

test('قراءة الأرقام العربية والكسور', () => {
  assert.equal(parseNum('١٥٠'), 150);
  assert.equal(parseNum('2٫5'), 2.5);
  assert.equal(parseNum('1/2'), 0.5);
  assert.ok(Number.isNaN(parseNum('')));
  assert.equal(roundTo(0.1 + 0.2, 2), 0.3);
});

test('البحث يتجاهل الهمزات والتاء المربوطة', () => {
  assert.equal(normalizeAr('أرز'), 'ارز');
  assert.ok(matchesQuery('أرز (حجم كوب الروب)', 'ارز'));
  assert.ok(matchesQuery('بطاطة صغيرة', 'بطاطه'));
  assert.ok(matchesQuery('برتقال – تفاح – كمثرى – خوخ', 'تفاح'));
  assert.ok(!matchesQuery('موز', 'تفاح'));
});

test('عرض الكميات', () => {
  assert.equal(fmtQty(0.5), '½');
  assert.equal(fmtQty(4.5), '4½');
  assert.equal(fmtQty(1.25), '1¼');
  assert.equal(refLabel(seed('s008')), '1 كوب (250 مل)');
  assert.equal(refLabel(seed('s021')), 'الكمية غير محددة');
});

test('التحقق من نموذج الصنف', () => {
  assert.deepEqual(validateFood({ name: 'x', category: 'other', refQty: 1, unit: 'حبة', carbs: 0 }), []);
  assert.ok(validateFood({ name: '', category: 'other', refQty: 0, unit: '', carbs: '' }).length >= 4);
  assert.ok(validateFood({ name: 'x', category: 'other', refQty: 1, unit: 'حبة', carbs: 5, altQty: 10, altUnit: '' }).length === 1);
});

test('سلامة قاعدة البيانات المستخرجة', () => {
  const cats = new Set(CATEGORIES.map((c) => c.id));
  const ids = new Set();
  assert.equal(SEED_FOODS.length, 122);
  for (const f of SEED_FOODS) {
    assert.ok(!ids.has(f.seedId), `معرّف مكرر ${f.seedId}`);
    ids.add(f.seedId);
    assert.ok(f.name.trim(), f.seedId);
    assert.ok(cats.has(f.category), `${f.name}: تصنيف غير معروف`);
    assert.ok(f.unit, `${f.name}: بدون وحدة`);
    assert.ok(f.source, `${f.name}: بدون مصدر`);
    if (!isComplete(f)) assert.ok(f.note, `${f.name}: ناقص بدون ملاحظة`);
    if (f.altQty != null) assert.ok(hasAlt(f), f.name);
  }
  // أسماء مكررة بنفس الوحدة = تكرار فعلي
  const keys = SEED_FOODS.map((f) => `${f.name}|${f.unit}`);
  assert.equal(new Set(keys).size, keys.length, 'يوجد صنف مكرر');
});

test('السجل: اليوم من التاريخ والوقت بنظام 12 ساعة', () => {
  assert.equal(weekdayName('2026-11-18'), 'الأربعاء');
  assert.equal(weekdayName('2026-11-20'), 'الجمعة');
  assert.equal(weekdayName('bad'), '');
  assert.equal(formatTime12('13:05'), '1:05 م');
  assert.equal(formatTime12('00:30'), '12:30 ص');
  assert.equal(formatTime12('12:00'), '12:00 م');
  assert.ok(isValidDateStr('2026-02-28'));
  assert.ok(!isValidDateStr('2026-02-30'));
});

test('السجل: موعد القياس بعد ساعتين (حتى لو عبر منتصف الليل)', () => {
  const d = dueTime({ date: '2026-11-18', time: '23:15' });
  assert.equal(todayStr(d), '2026-11-19');
  assert.equal(`${d.getHours()}:${d.getMinutes()}`, '1:15');
  const d2 = dueTime({ date: '2026-11-18', time: '13:30' });
  assert.equal(`${d2.getHours()}:${d2.getMinutes()}`, '15:30');
});

test('السجل: التصدير إلى CSV مرتب زمنياً', () => {
  const csv = logsToCSV([
    { date: '2026-11-18', time: '19:00', mealType: 'عشاء', bgBefore: 140, dose: 3, bgAfter: 160, unit: 'mg/dL', meal: { name: 'عشاء', items: [], totalCarbs: 75 } },
    { date: '2026-11-18', time: '08:00', mealType: 'فطور', bgBefore: 110, dose: 2.5, bgAfter: null, unit: 'mg/dL', meal: { name: 'فطور', items: [{ name: 'توست (أسمر أو أبيض)', qty: '2 حبة', carbs: 30 }], totalCarbs: 30 }, note: 'قبل الرياضة, صباحاً' },
  ]);
  const lines = csv.replace('\uFEFF', '').split('\n');
  assert.equal(lines.length, 3);
  assert.match(lines[1], /^2026-11-18,الأربعاء,08:00,فطور,110,/);
  assert.match(lines[1], /"قبل الرياضة, صباحاً"$/);
  assert.match(lines[2], /19:00,عشاء,140,عشاء,75,3,160,mg\/dL,$/);
});
