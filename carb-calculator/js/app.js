// حاسبة الكربوهيدرات والإنسولين — منطق الواجهة
import { h, clear, toast, modal, confirmDialog, promptDialog, download, pickFile, resizeImage } from './ui.js';
import { CATEGORIES, getCategory, resolveCategory } from './categories.js';
import {
  DEFAULT_RATIO, UNIT_SUGGESTIONS, GLUCOSE_UNITS, carbsFor, sumCarbs, roundTo, insulinDose, formatDose, fmt, fmtQty,
  parseNum, matchesQuery, refLabel, qtyLabel, isComplete, hasAlt, isWeightUnit, validateFood,
} from './calc.js';
import * as db from './db.js';
import { renderLog, openLogForm, mealFromItems } from './log.js';

const state = {
  foods: [],
  meals: [],
  logs: [],
  ratio: DEFAULT_RATIO,
  glucoseUnit: 'mg/dL',
  current: { items: [], editingMealId: null, editingName: '' },
  view: 'calc',
  calc: { query: '', cat: null },
  manage: { query: '', cat: '', onlyIncomplete: false },
};

const $ = (sel) => document.querySelector(sel);
const foodById = (id) => state.foods.find((f) => f.id === id);

/* ───────────── البيانات ───────────── */

async function loadAll() {
  await db.ensureSeed();
  state.foods = await db.foods.all();
  state.meals = await db.meals.all();
  state.ratio = Number(await db.settings.get('ratio', DEFAULT_RATIO)) || DEFAULT_RATIO;
  state.current = await db.settings.get('currentMeal', state.current);
  state.glucoseUnit = await db.settings.get('glucoseUnit', 'mg/dL');
  state.logs = await db.logs.all();
  sortFoods();
}

/** ما تحتاجه صفحة السجل من التطبيق */
const ctx = {
  state,
  render: () => render(),
  itemFood: (it) => itemFood(it),
  itemCarbs: (it) => itemCarbs(it),
  mealTotal: (items) => mealTotal(items),
  qtyLabel: (it, food) => qtyLabel(it, food),
  defaultMealName: () => defaultMealName(),
  emptyState: (...a) => emptyState(...a),
};

function sortFoods() {
  state.foods.sort((a, b) => a.name.localeCompare(b.name, 'ar'));
}

function saveCurrent() {
  return db.settings.set('currentMeal', state.current);
}

/** بيانات الصنف المستخدمة لعنصر في الوجبة: النسخة الحالية من القاعدة، أو النسخة المحفوظة إن حُذف */
function itemFood(item) {
  return foodById(item.foodId) || item.snapshot;
}

function itemCarbs(item) {
  return carbsFor(itemFood(item), item.qty, item.mode);
}

function mealTotal(items) {
  return roundTo(sumCarbs(items.map(itemCarbs)), 1);
}

/* ───────────── التنقل ───────────── */

const VIEWS = {
  calc: { title: 'الحاسبة', icon: '🧮', render: renderCalc },
  meals: { title: 'الوجبات', icon: '📋', render: renderMeals },
  log: { title: 'السجل', icon: '📝', render: (root) => renderLog(root, ctx) },
  foods: { title: 'الأطعمة', icon: '🗂️', render: renderManage },
  setup: { title: 'الإعدادات', icon: '⚙️', render: renderSettings },
};

function route() {
  const v = location.hash.replace('#', '');
  state.view = VIEWS[v] ? v : 'calc';
  document.querySelectorAll('[data-nav]').forEach((a) => {
    a.classList.toggle('active', a.dataset.nav === state.view);
    a.setAttribute('aria-current', a.dataset.nav === state.view ? 'page' : 'false');
  });
  render();
  window.scrollTo(0, 0);
}

function render() {
  VIEWS[state.view].render($('#view'));
}

function buildNav() {
  const items = Object.entries(VIEWS).map(([id, v]) =>
    h('a', { href: `#${id}`, class: 'nav-link', dataset: { nav: id } },
      h('span', { class: 'nav-icon', 'aria-hidden': 'true' }, v.icon),
      h('span', {}, v.title)));
  clear($('#top-nav'), items);
  clear($('#bottom-nav'), items.map((n) => n.cloneNode(true)));
}

/* ───────────── مكونات مشتركة ───────────── */

function foodThumb(food) {
  const cat = getCategory(food.category);
  if (food.image) return h('img', { class: 'thumb', src: food.image, alt: '' });
  return h('span', { class: 'thumb', style: { background: `var(--cat-${cat.id})` }, 'aria-hidden': 'true' }, cat.icon);
}

function carbsBadge(food) {
  if (!isComplete(food)) return h('span', { class: 'badge warn' }, 'بيانات ناقصة');
  return h('span', { class: 'badge carbs' }, `${fmt(Number(food.carbs), 2)} جم`);
}

function emptyState(icon, text, action) {
  return h('div', { class: 'empty' }, h('div', { class: 'empty-icon' }, icon), h('p', {}, text), action);
}

/* ───────────── صفحة الحاسبة ───────────── */

function renderCalc(root) {
  const search = h('input', {
    class: 'input search', type: 'search', placeholder: 'ابحث عن صنف… (مثال: خبز، أرز، حليب)',
    value: state.calc.query, 'aria-label': 'بحث عن صنف', autocomplete: 'off',
    oninput: (e) => { state.calc.query = e.target.value; renderFoodResults(); },
  });
  const chips = h('div', { class: 'chips', role: 'tablist', 'aria-label': 'التصنيفات' },
    h('button', { class: `chip${!state.calc.cat ? ' active' : ''}`, onclick: () => setCat(null) }, '🔎 الكل'),
    CATEGORIES.map((c) => h('button', {
      class: `chip${state.calc.cat === c.id ? ' active' : ''}`, onclick: () => setCat(c.id),
    }, `${c.icon} ${c.name}`)));

  clear(root,
    h('div', { class: 'calc-layout' },
      h('section', { class: 'col-foods', 'aria-label': 'اختيار الأطعمة' },
        h('div', { class: 'search-bar' }, search, chips),
        h('div', { id: 'food-results' })),
      h('aside', { class: 'col-meal' },
        h('section', { class: 'card', id: 'meal-card' }),
        h('section', { class: 'card insulin', id: 'insulin-card' }))),
    // شريط عائم على الجوال يُظهر الإجمالي والجرعة دون الحاجة للتمرير
    h('button', {
      id: 'meal-fab', class: 'meal-fab', type: 'button', hidden: true,
      onclick: () => $('#meal-card').scrollIntoView({ behavior: 'smooth', block: 'start' }),
    }));
  renderFoodResults();
  renderMealCard();
  renderInsulinCard();
}

function setCat(cat) {
  state.calc.cat = cat;
  document.querySelectorAll('.chips .chip').forEach((b, i) =>
    b.classList.toggle('active', (i === 0 && !cat) || (i > 0 && CATEGORIES[i - 1].id === cat)));
  renderFoodResults();
  const active = document.querySelector('.chips .chip.active');
  active?.scrollIntoView({ block: 'nearest', inline: 'center', behavior: 'smooth' });
}

function renderFoodResults() {
  const box = $('#food-results');
  if (!box) return;
  const { query, cat } = state.calc;

  if (!state.foods.length) {
    clear(box, emptyState('🗂️', 'لا توجد أصناف في قاعدة البيانات.',
      h('a', { class: 'btn primary', href: '#foods' }, 'إضافة أصناف')));
    return;
  }

  // بدون بحث أو تصنيف: بطاقات التصنيفات
  if (!query.trim() && !cat) {
    clear(box, h('div', { class: 'cat-grid' }, CATEGORIES.map((c) => {
      const count = state.foods.filter((f) => f.category === c.id).length;
      return h('button', { class: 'cat-card', style: { background: `var(--cat-${c.id})` }, onclick: () => setCat(c.id) },
        h('span', { class: 'cat-icon', 'aria-hidden': 'true' }, c.icon),
        h('span', { class: 'cat-name' }, c.name),
        h('span', { class: 'cat-count' }, `${count} صنف`));
    })));
    return;
  }

  const list = state.foods.filter((f) => (!cat || f.category === cat) && matchesQuery(f.name, query));
  if (!list.length) {
    clear(box, emptyState('🔍', 'لا توجد نتائج مطابقة.',
      h('button', { class: 'btn', onclick: () => openFoodForm({ name: query.trim(), category: cat || 'other' }) }, '➕ إضافة صنف جديد')));
    return;
  }
  clear(box,
    h('p', { class: 'muted small' }, `${list.length} صنف${cat ? ` في «${getCategory(cat).name}»` : ''}`),
    h('ul', { class: 'food-list' }, list.map((f) =>
      h('li', {},
        h('button', { class: 'food-row', onclick: () => openQtyDialog(f) },
          foodThumb(f),
          h('span', { class: 'food-info' },
            h('span', { class: 'food-name' }, f.name),
            h('span', { class: 'food-ref' }, refLabel(f))),
          carbsBadge(f),
          h('span', { class: 'add-icon', 'aria-hidden': 'true' }, '+'))))));
}

/** نافذة تحديد الكمية — للإضافة (item = null) أو لتعديل عنصر موجود */
function openQtyDialog(food, item = null) {
  if (!isComplete(food)) {
    modal({
      title: food.name,
      content: h('div', {},
        h('p', {}, 'بيانات هذا الصنف ناقصة في الجدول الأصلي، ولا يمكن حسابه قبل إكمالها.'),
        food.note && h('p', { class: 'note' }, food.note)),
      actions: [
        { label: 'إكمال البيانات', class: 'primary', onClick: () => openFoodForm(food) },
        { label: 'إغلاق', class: 'ghost' },
      ],
    });
    return;
  }

  let mode = item?.mode || 'unit';
  const unitOf = () => (mode === 'alt' ? food.altUnit : food.unit);
  const refOf = () => Number(mode === 'alt' ? food.altQty : food.refQty);
  const defaultQty = () => refOf();

  const qtyInput = h('input', {
    class: 'input qty-input', inputmode: 'decimal', 'aria-label': 'الكمية',
    value: String(roundTo(item ? item.qty : defaultQty(), 2)),
    oninput: update,
  });
  const unitLbl = h('span', { class: 'qty-unit' });
  const result = h('div', { class: 'qty-result', 'aria-live': 'polite' });
  const presets = h('div', { class: 'presets' });

  const stepOf = () => (isWeightUnit(unitOf()) ? 10 : (refOf() >= 1 ? 1 : refOf()));
  const bump = (dir) => {
    const v = parseNum(qtyInput.value) || 0;
    qtyInput.value = String(roundTo(Math.max(0, v + dir * stepOf()), 2));
    update();
  };

  const modeSwitch = hasAlt(food) && h('div', { class: 'segmented', role: 'radiogroup', 'aria-label': 'طريقة إدخال الكمية' },
    [['unit', food.unit], ['alt', food.altUnit]].map(([m, label]) => h('button', {
      type: 'button', role: 'radio', class: m === mode ? 'active' : '',
      onclick: (e) => {
        if (mode === m) return;
        // تحويل الكمية الحالية إلى الوحدة الأخرى للحفاظ على نفس الكربوهيدرات
        const v = parseNum(qtyInput.value);
        const factor = Number(food.altQty) / Number(food.refQty);
        mode = m;
        if (v > 0) qtyInput.value = String(roundTo(m === 'alt' ? v * factor : v / factor, 2));
        e.target.parentElement.querySelectorAll('button').forEach((b) => b.classList.toggle('active', b === e.target));
        update();
      },
    }, `بـ${label}`)));

  function renderPresets() {
    const ref = refOf();
    const vals = isWeightUnit(unitOf())
      ? [...new Set([ref, 50, 100, 150, 200, 250].filter((v) => v > 0))].sort((a, b) => a - b)
      : [...new Set([ref / 2, ref, ref * 2, ref * 3].map((v) => roundTo(v, 2)))];
    clear(presets, vals.map((v) => h('button', {
      type: 'button', class: 'chip small',
      onclick: () => { qtyInput.value = String(v); update(); },
    }, `${fmtQty(v)} ${unitOf()}`)));
  }

  function update() {
    unitLbl.textContent = unitOf();
    const q = parseNum(qtyInput.value);
    const c = carbsFor(food, q, mode);
    if (!(q > 0) || !Number.isFinite(c)) {
      clear(result, h('span', { class: 'muted' }, 'أدخل كمية أكبر من صفر'));
      return;
    }
    clear(result,
      h('div', { class: 'qty-carbs' }, h('strong', {}, fmt(c, 1)), ' جم كربوهيدرات'),
      h('div', { class: 'equation', dir: 'ltr' }, `${fmt(q, 2)} ÷ ${fmt(refOf(), 2)} × ${fmt(Number(food.carbs), 2)} = ${fmt(c, 2)}`));
  }

  const content = h('div', { class: 'qty-dialog' },
    h('div', { class: 'qty-head' }, foodThumb(food),
      h('div', {},
        h('div', { class: 'muted small' }, 'المرجع حسب الجدول'),
        h('div', {}, `${refLabel(food)} = `, h('strong', {}, `${fmt(Number(food.carbs), 2)} جم كربوهيدرات`)))),
    food.note && h('p', { class: 'note' }, food.note),
    modeSwitch,
    h('label', { class: 'field' }, h('span', {}, 'الكمية'),
      h('div', { class: 'stepper' },
        h('button', { type: 'button', class: 'step-btn', 'aria-label': 'زيادة', onclick: () => bump(1) }, '+'),
        qtyInput, unitLbl,
        h('button', { type: 'button', class: 'step-btn', 'aria-label': 'إنقاص', onclick: () => bump(-1) }, '−'))),
    presets,
    result);

  const submit = async () => {
    const q = parseNum(qtyInput.value);
    if (!(q > 0) || !Number.isFinite(carbsFor(food, q, mode))) {
      qtyInput.focus();
      toast('أدخل كمية صحيحة أكبر من صفر', 'error');
      return false;
    }
    const snapshot = { ...food, image: null };
    if (item) {
      Object.assign(item, { qty: q, mode, snapshot });
      toast('تم تعديل الكمية');
    } else {
      state.current.items.push({ uid: db.uid(), foodId: food.id, qty: q, mode, snapshot });
      toast(`أُضيف «${food.name}» إلى الوجبة`);
    }
    await saveCurrent();
    renderMealCard();
    renderInsulinCard();
  };

  const dlg = modal({
    title: food.name,
    content,
    actions: [
      { label: item ? 'حفظ التعديل' : 'إضافة إلى الوجبة', class: 'primary', onClick: submit },
      { label: 'إلغاء', class: 'ghost' },
    ],
  });
  qtyInput.addEventListener('keydown', async (e) => {
    if (e.key === 'Enter' && (await submit()) !== false) dlg.close();
  });
  renderPresets();
  update();
  // إعادة بناء أزرار الكميات السريعة عند تبديل الوحدة
  modeSwitch && modeSwitch.addEventListener('click', renderPresets);
}

function renderMealCard() {
  const card = $('#meal-card');
  if (!card) return;
  const { items, editingMealId, editingName } = state.current;
  const total = mealTotal(items);

  const head = h('div', { class: 'card-head' },
    h('h2', {}, '🍽️ مكونات الوجبة الحالية'),
    items.length > 0 && h('span', { class: 'muted small' }, `${items.length} صنف`));

  const editingBanner = editingMealId && h('div', { class: 'banner' },
    `تعديل الوجبة المحفوظة: «${editingName}»`,
    h('button', { class: 'link-btn', onclick: stopEditing }, 'إلغاء التعديل'));

  if (!items.length) {
    clear(card, head, editingBanner,
      emptyState('🥗', 'لم تُضف أي أصناف بعد. اختر الأطعمة من القائمة لإضافتها إلى الوجبة.'));
    return;
  }

  const rows = items.map((it) => {
    const food = itemFood(it);
    const c = itemCarbs(it);
    const deleted = !foodById(it.foodId);
    return h('tr', {},
      h('td', { class: 'td-name' }, food.name, deleted && h('span', { class: 'badge warn tiny' }, 'محذوف من القاعدة')),
      h('td', { class: 'td-qty' }, qtyLabel(it, food)),
      h('td', { class: 'td-carbs' }, Number.isFinite(c) ? `${fmt(c, 1)} جم` : '—'),
      h('td', { class: 'td-actions' },
        h('button', { class: 'icon-btn', title: 'تعديل الكمية', 'aria-label': `تعديل كمية ${food.name}`, onclick: () => openQtyDialog(food, it) }, '✏️'),
        h('button', { class: 'icon-btn', title: 'حذف', 'aria-label': `حذف ${food.name}`, onclick: () => removeItem(it.uid) }, '🗑️')));
  });

  clear(card, head, editingBanner,
    h('div', { class: 'table-wrap' },
      h('table', { class: 'meal-table' },
        h('thead', {}, h('tr', {}, h('th', {}, 'الصنف'), h('th', {}, 'الكمية'), h('th', {}, 'الكربوهيدرات'), h('th', { class: 'sr' }, 'إجراءات'))),
        h('tbody', {}, rows),
        h('tfoot', {}, h('tr', {}, h('th', { colspan: 2 }, 'الإجمالي'), h('th', { class: 'td-carbs total', id: 'meal-total' }, `${fmt(total, 1)} جم`), h('th', {}))))),
    h('div', { class: 'row-actions' },
      editingMealId
        ? [h('button', { class: 'btn primary', onclick: () => saveMeal(true) }, '💾 تحديث الوجبة المحفوظة'),
          h('button', { class: 'btn', onclick: () => saveMeal(false) }, 'حفظ كوجبة جديدة')]
        : h('button', { class: 'btn primary', onclick: () => saveMeal(false) }, '💾 حفظ الوجبة'),
      h('button', { class: 'btn ghost', onclick: clearMeal }, 'مسح الوجبة')));
}

async function removeItem(uid) {
  state.current.items = state.current.items.filter((i) => i.uid !== uid);
  await saveCurrent();
  renderMealCard();
  renderInsulinCard();
}

async function clearMeal() {
  if (!(await confirmDialog('مسح جميع أصناف الوجبة الحالية؟', { okLabel: 'مسح', danger: true }))) return;
  state.current = { items: [], editingMealId: null, editingName: '' };
  await saveCurrent();
  renderMealCard();
  renderInsulinCard();
}

async function stopEditing() {
  state.current = { items: [], editingMealId: null, editingName: '' };
  await saveCurrent();
  renderMealCard();
  renderInsulinCard();
}

async function saveMeal(update) {
  const items = state.current.items;
  if (!items.length) return;
  let meal;
  if (update) {
    meal = state.meals.find((m) => m.id === state.current.editingMealId);
  }
  if (!meal) {
    const name = await promptDialog('حفظ الوجبة', { label: 'اسم الوجبة', value: defaultMealName() });
    if (!name) return;
    meal = { id: db.uid(), name, createdAt: Date.now() };
    state.meals.push(meal);
  }
  meal.items = items.map((i) => ({ ...i }));
  meal.totalCarbs = mealTotal(items);
  meal.updatedAt = Date.now();
  await db.meals.save(meal);
  state.current.editingMealId = meal.id;
  state.current.editingName = meal.name;
  await saveCurrent();
  toast(update ? 'تم تحديث الوجبة المحفوظة' : `تم حفظ «${meal.name}»`);
  renderMealCard();
}

function defaultMealName() {
  const hr = new Date().getHours();
  const label = hr < 11 ? 'فطور' : hr < 17 ? 'غداء' : 'عشاء';
  return `${label} ${new Date().toLocaleDateString('ar', { day: 'numeric', month: 'long' })}`;
}

function renderInsulinCard() {
  const card = $('#insulin-card');
  if (!card) return;
  const total = mealTotal(state.current.items);
  const dose = insulinDose(total, state.ratio);
  const fab = $('#meal-fab');
  if (fab) {
    const n = state.current.items.length;
    fab.hidden = n === 0;
    clear(fab,
      h('span', {}, `🍽️ ${n} صنف`),
      h('span', {}, h('strong', {}, fmt(total, 1)), ' جم'),
      h('span', { class: 'fab-dose' }, '💉 ', h('strong', {}, formatDose(dose)), ' وحدة'),
      h('span', { 'aria-hidden': 'true' }, '⌄'));
  }
  clear(card,
    h('div', { class: 'card-head' }, h('h2', {}, '💉 حاسبة جرعة الإنسولين')),
    h('dl', { class: 'insulin-grid' },
      h('div', {}, h('dt', {}, 'إجمالي كربوهيدرات الوجبة'), h('dd', {}, h('strong', {}, fmt(total, 1)), ' جم')),
      h('div', {}, h('dt', {}, 'معامل الكربوهيدرات (ICR)'),
        h('dd', {}, h('strong', {}, fmt(state.ratio, 2)), ' جم لكل وحدة ',
          h('a', { href: '#setup', class: 'link-btn' }, 'تغيير')))),
    h('div', { class: 'dose' },
      h('div', { class: 'dose-label' }, 'جرعة الإنسولين الحسابية'),
      h('div', { class: 'dose-value', id: 'dose-value' }, formatDose(dose), h('span', {}, ' وحدة')),
      h('div', { class: 'equation', dir: 'ltr' }, `${fmt(total, 1)} ÷ ${fmt(state.ratio, 2)} = ${formatDose(dose)}`)),
    state.current.items.length > 0 && h('button', {
      class: 'btn log-btn', id: 'log-from-calc',
      onclick: () => openLogForm(ctx, { meal: mealFromItems(ctx, state.current.editingName || defaultMealName(), state.current.items) }),
    }, '📝 تسجيل الوجبة في السجل (مع قياس السكر والجرعة)'),
    h('p', { class: 'disclaimer' },
      '⚠️ تنبيه طبي: هذه النتيجة ناتج معادلة حسابية فقط (إجمالي الكربوهيدرات ÷ المعامل)، وليست وصفة طبية أو أمراً بإعطاء جرعة. ',
      'لا تتضمن جرعات تصحيحية ولا تقريباً للجرعة. يجب أن يكون المعامل معتمداً من الطبيب، وراجع خطة العلاج المعتمدة قبل أي جرعة.'));
}

/* ───────────── صفحة سجل الوجبات ───────────── */

function renderMeals(root) {
  const list = [...state.meals].sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, '📋 الوجبات المحفوظة'),
      h('span', { class: 'muted' }, `${list.length} وجبة`)),
    !list.length
      ? emptyState('📋', 'لا توجد وجبات محفوظة بعد. أنشئ وجبة في الحاسبة ثم اضغط «حفظ الوجبة».',
        h('a', { class: 'btn primary', href: '#calc' }, 'الذهاب إلى الحاسبة'))
      : h('div', { class: 'meal-cards' }, list.map(mealCard)));
}

function mealCard(meal) {
  const total = mealTotal(meal.items);
  const dose = insulinDose(total, state.ratio);
  return h('article', { class: 'card meal-saved' },
    h('div', { class: 'card-head' },
      h('div', {},
        h('h2', {}, meal.name),
        h('div', { class: 'muted small' }, new Date(meal.updatedAt || meal.createdAt).toLocaleString('ar', { dateStyle: 'medium', timeStyle: 'short' }))),
      h('div', { class: 'meal-total' }, h('strong', {}, fmt(total, 1)), h('span', {}, 'جم كربوهيدرات'))),
    h('details', {},
      h('summary', {}, `${meal.items.length} صنف — عرض المكونات`),
      h('ul', { class: 'meal-items' }, meal.items.map((it) => {
        const food = itemFood(it);
        return h('li', {}, h('span', {}, food.name), h('span', { class: 'muted' }, qtyLabel(it, food)),
          h('span', {}, `${fmt(itemCarbs(it), 1)} جم`));
      })),
      h('p', { class: 'muted small' }, `الناتج الحسابي بالمعامل الحالي (${fmt(state.ratio, 2)}): ${formatDose(dose)} وحدة`)),
    h('div', { class: 'row-actions' },
      h('button', { class: 'btn primary', onclick: () => loadMeal(meal, false) }, '↩️ استخدام'),
      h('button', { class: 'btn', onclick: () => loadMeal(meal, true) }, '✏️ تعديل'),
      h('button', { class: 'btn', onclick: () => openLogForm(ctx, { meal: mealFromItems(ctx, meal.name, meal.items) }) }, '📝 تسجيل'),
      h('button', { class: 'btn', onclick: () => renameMeal(meal) }, 'إعادة تسمية'),
      h('button', { class: 'btn danger-ghost', onclick: () => deleteMeal(meal) }, '🗑️ حذف')));
}

async function loadMeal(meal, edit) {
  if (state.current.items.length && !state.current.editingMealId) {
    const ok = await confirmDialog('ستُستبدل الوجبة الحالية غير المحفوظة. متابعة؟', { okLabel: 'متابعة' });
    if (!ok) return;
  }
  state.current = {
    items: meal.items.map((i) => ({ ...i, uid: db.uid() })),
    editingMealId: edit ? meal.id : null,
    editingName: edit ? meal.name : '',
  };
  await saveCurrent();
  location.hash = '#calc';
  toast(edit ? 'عدّل الوجبة ثم اضغط «تحديث الوجبة المحفوظة»' : `تم تحميل «${meal.name}»`);
}

async function renameMeal(meal) {
  const name = await promptDialog('إعادة تسمية الوجبة', { label: 'الاسم الجديد', value: meal.name });
  if (!name) return;
  meal.name = name;
  await db.meals.save(meal);
  if (state.current.editingMealId === meal.id) { state.current.editingName = name; await saveCurrent(); }
  render();
}

async function deleteMeal(meal) {
  if (!(await confirmDialog(`حذف الوجبة «${meal.name}»؟`, { okLabel: 'حذف', danger: true }))) return;
  await db.meals.remove(meal.id);
  state.meals = state.meals.filter((m) => m.id !== meal.id);
  if (state.current.editingMealId === meal.id) {
    state.current.editingMealId = null;
    state.current.editingName = '';
    await saveCurrent();
  }
  toast('تم حذف الوجبة');
  render();
}

/* ───────────── صفحة إدارة الأطعمة ───────────── */

function renderManage(root) {
  const incompleteCount = state.foods.filter((f) => !isComplete(f)).length;
  clear(root,
    h('div', { class: 'page-head' },
      h('h1', {}, '🗂️ إدارة الأطعمة'),
      h('button', { class: 'btn primary', onclick: () => openFoodForm() }, '➕ إضافة صنف')),
    h('div', { class: 'filters' },
      h('input', {
        class: 'input search', type: 'search', placeholder: 'ابحث عن صنف موجود…', value: state.manage.query,
        'aria-label': 'بحث في الأصناف',
        oninput: (e) => { state.manage.query = e.target.value; renderManageList(); },
      }),
      h('select', {
        class: 'input', 'aria-label': 'تصفية حسب التصنيف',
        onchange: (e) => { state.manage.cat = e.target.value; renderManageList(); },
      },
      h('option', { value: '' }, 'كل التصنيفات'),
      CATEGORIES.map((c) => h('option', { value: c.id, selected: state.manage.cat === c.id }, `${c.icon} ${c.name}`))),
      incompleteCount > 0 && h('label', { class: 'check' },
        h('input', {
          type: 'checkbox', checked: state.manage.onlyIncomplete,
          onchange: (e) => { state.manage.onlyIncomplete = e.target.checked; renderManageList(); },
        }),
        `الناقصة فقط (${incompleteCount})`)),
    h('div', { id: 'manage-list' }));
  renderManageList();
}

function renderManageList() {
  const box = $('#manage-list');
  if (!box) return;
  const { query, cat, onlyIncomplete } = state.manage;
  const list = state.foods.filter((f) =>
    (!cat || f.category === cat) && matchesQuery(f.name, query) && (!onlyIncomplete || !isComplete(f)));
  if (!list.length) {
    clear(box, emptyState('🔍', 'لا توجد أصناف مطابقة.'));
    return;
  }
  clear(box,
    h('p', { class: 'muted small' }, `${list.length} من ${state.foods.length} صنف`),
    h('ul', { class: 'food-list manage' }, list.map((f) => {
      const cat = getCategory(f.category);
      return h('li', { class: 'food-row static' },
        foodThumb(f),
        h('span', { class: 'food-info' },
          h('span', { class: 'food-name' }, f.name),
          h('span', { class: 'food-ref' }, `${refLabel(f)} • ${cat.icon} ${cat.name}`),
          f.note && h('span', { class: 'food-note' }, f.note)),
        carbsBadge(f),
        h('span', { class: 'row-btns' },
          h('button', { class: 'icon-btn', title: 'تعديل', 'aria-label': `تعديل ${f.name}`, onclick: () => openFoodForm(f) }, '✏️'),
          h('button', { class: 'icon-btn', title: 'حذف', 'aria-label': `حذف ${f.name}`, onclick: () => deleteFood(f) }, '🗑️')));
    })));
}

function openFoodForm(food = null) {
  const isEdit = !!food?.id;
  const data = { name: '', category: 'other', refQty: '', unit: 'حبة', carbs: '', altQty: '', altUnit: '', note: '', image: null, ...(food || {}) };
  // عرض القيم الكسرية بشكل مقروء (1/3) والإبقاء على القيمة الأصلية الدقيقة إن لم تُعدّل
  const val = (v) => {
    if (v == null || v === '') return '';
    const n = Number(v);
    for (const d of [3, 6, 8]) {
      const k = n * d;
      if (Math.abs(k - Math.round(k)) < 1e-9 && roundTo(n, 4) !== n) return `${Math.round(k)}/${d}`;
    }
    return String(roundTo(n, 4));
  };
  const keep = (key) => (inputs[key].value.trim() === val(data[key]) && data[key] != null ? data[key] : null);

  const field = (label, input, hint) => h('label', { class: 'field' }, h('span', {}, label), input, hint && h('small', { class: 'muted' }, hint));
  const unitList = h('datalist', { id: 'unit-list' }, UNIT_SUGGESTIONS.map((u) => h('option', { value: u })));

  const inputs = {
    name: h('input', { class: 'input', value: data.name, required: true }),
    category: h('select', { class: 'input' }, CATEGORIES.map((c) => h('option', { value: c.id, selected: data.category === c.id }, `${c.icon} ${c.name}`))),
    refQty: h('input', { class: 'input', inputmode: 'decimal', value: val(data.refQty), placeholder: 'مثال: 1 أو 100 أو 1/2' }),
    unit: h('input', { class: 'input', value: data.unit, list: 'unit-list', placeholder: 'حبة، كوب، جرام…' }),
    carbs: h('input', { class: 'input', inputmode: 'decimal', value: val(data.carbs), placeholder: 'مثال: 15' }),
    altQty: h('input', { class: 'input', inputmode: 'decimal', value: val(data.altQty), placeholder: 'اختياري — مثال: 250' }),
    altUnit: h('input', { class: 'input', value: data.altUnit, list: 'unit-list', placeholder: 'اختياري — مثال: مل أو جرام' }),
    note: h('input', { class: 'input', value: data.note, placeholder: 'اختياري' }),
  };
  let image = data.image;
  const preview = h('div', { class: 'img-preview' });
  const renderPreview = () => clear(preview,
    image ? h('img', { src: image, alt: 'صورة الصنف' }) : h('span', { class: 'muted small' }, 'لا توجد صورة'),
    h('button', {
      type: 'button', class: 'btn small', onclick: async () => {
        const file = await pickFile('image/*');
        if (!file) return;
        try { image = await resizeImage(file); renderPreview(); } catch { toast('تعذر قراءة الصورة', 'error'); }
      },
    }, image ? 'تغيير الصورة' : '📷 إضافة صورة'),
    image && h('button', { type: 'button', class: 'btn small ghost', onclick: () => { image = null; renderPreview(); } }, 'إزالة'));
  renderPreview();

  const errorsBox = h('div', { class: 'form-errors', role: 'alert' });
  const content = h('form', { class: 'food-form', onsubmit: (e) => e.preventDefault() },
    unitList,
    field('اسم الصنف *', inputs.name),
    field('التصنيف *', inputs.category),
    h('div', { class: 'grid-2' },
      field('الكمية المرجعية *', inputs.refQty),
      field('نوع الوحدة *', inputs.unit)),
    field('كمية الكربوهيدرات بالجرام *', inputs.carbs, 'الكربوهيدرات الموجودة في الكمية المرجعية أعلاه'),
    h('fieldset', { class: 'fieldset' },
      h('legend', {}, 'قياس مكافئ (اختياري)'),
      h('small', { class: 'muted' }, 'يتيح إدخال الكمية بطريقة ثانية، مثال: 1 كوب = 250 مل، أو 1 حبة = 60 جرام'),
      h('div', { class: 'grid-2' }, field('الكمية المكافئة', inputs.altQty), field('وحدتها', inputs.altUnit))),
    field('ملاحظة', inputs.note),
    h('div', { class: 'field' }, h('span', {}, 'صورة الصنف (اختياري)'), preview),
    food?.source && h('p', { class: 'muted small' }, `المصدر: ${food.source}`),
    errorsBox);

  modal({
    title: isEdit ? 'تعديل صنف' : 'إضافة صنف جديد',
    content,
    wide: true,
    actions: [
      { label: isEdit ? 'حفظ التعديلات' : 'إضافة الصنف', class: 'primary', onClick: async () => {
        const f = {
          ...(food || {}),
          name: inputs.name.value.trim(),
          category: inputs.category.value,
          refQty: keep('refQty') ?? parseNum(inputs.refQty.value),
          unit: inputs.unit.value.trim(),
          carbs: inputs.carbs.value.trim() === '' ? '' : (keep('carbs') ?? parseNum(inputs.carbs.value)),
          altQty: inputs.altQty.value.trim() === '' ? '' : (keep('altQty') ?? parseNum(inputs.altQty.value)),
          altUnit: inputs.altUnit.value.trim(),
          note: inputs.note.value.trim(),
          image,
        };
        const errors = validateFood(f);
        if (errors.length) {
          clear(errorsBox, h('ul', {}, errors.map((e) => h('li', {}, e))));
          return false;
        }
        if (f.altQty === '') { f.altQty = null; f.altUnit = ''; }
        const saved = await db.foods.save(f);
        const i = state.foods.findIndex((x) => x.id === saved.id);
        if (i >= 0) state.foods[i] = saved; else state.foods.push(saved);
        sortFoods();
        toast(isEdit ? 'تم حفظ التعديلات' : `تمت إضافة «${saved.name}»`);
        render();
      } },
      { label: 'إلغاء', class: 'ghost' },
    ],
  });
  setTimeout(() => (isEdit ? null : inputs.name.focus()), 50);
}

async function deleteFood(food) {
  const used = state.current.items.some((i) => i.foodId === food.id);
  const msg = `حذف «${food.name}» من قاعدة البيانات؟${used ? '\nالصنف موجود في الوجبة الحالية وسيبقى فيها بآخر بيانات محفوظة.' : ''}`;
  if (!(await confirmDialog(msg, { okLabel: 'حذف', danger: true }))) return;
  await db.foods.remove(food.id);
  state.foods = state.foods.filter((f) => f.id !== food.id);
  toast('تم حذف الصنف');
  render();
}

/* ───────────── صفحة الإعدادات ───────────── */

function renderSettings(root) {
  const ratioInput = h('input', { class: 'input ratio-input', inputmode: 'decimal', value: String(state.ratio), 'aria-label': 'معامل الكربوهيدرات' });
  const saveRatio = async () => {
    const r = parseNum(ratioInput.value);
    if (!(r > 0)) { toast('أدخل معاملاً أكبر من صفر', 'error'); return; }
    state.ratio = r;
    await db.settings.set('ratio', r);
    toast(`تم حفظ المعامل: ${fmt(r, 2)}`);
    render();
  };

  clear(root,
    h('div', { class: 'page-head' }, h('h1', {}, '⚙️ الإعدادات')),
    h('section', { class: 'card' },
      h('h2', {}, '💉 معامل الكربوهيدرات (Insulin to Carb Ratio)'),
      h('p', { class: 'muted' }, 'عدد جرامات الكربوهيدرات لكل وحدة إنسولين. القيمة الافتراضية: ', h('strong', {}, String(DEFAULT_RATIO)), '.'),
      h('div', { class: 'ratio-row' },
        ratioInput, h('span', {}, 'جم / وحدة'),
        h('button', { class: 'btn primary', onclick: saveRatio }, 'حفظ'),
        h('button', {
          class: 'btn ghost', onclick: async () => {
            state.ratio = DEFAULT_RATIO;
            await db.settings.set('ratio', DEFAULT_RATIO);
            toast('تمت استعادة القيمة الافتراضية 25');
            render();
          },
        }, 'استعادة الافتراضي (25)')),
      h('p', { class: 'disclaimer' }, '⚠️ يجب أن يكون المعامل معتمداً من الطبيب المعالج.')),

    h('section', { class: 'card' },
      h('h2', {}, '🩸 وحدة قياس السكر'),
      h('p', { class: 'muted' }, 'تُستخدم في السجل للتسجيلات الجديدة، والتسجيلات السابقة تحتفظ بوحدتها.'),
      h('div', { class: 'segmented unit-switch', role: 'radiogroup', 'aria-label': 'وحدة قياس السكر' },
        GLUCOSE_UNITS.map((u) => h('button', {
          type: 'button', role: 'radio', dir: 'ltr', class: state.glucoseUnit === u ? 'active' : '', 'aria-checked': String(state.glucoseUnit === u),
          onclick: async () => {
            state.glucoseUnit = u;
            await db.settings.set('glucoseUnit', u);
            toast(`وحدة السكر: ${u}`);
            render();
          },
        }, u)))),

    h('section', { class: 'card' },
      h('h2', {}, '🗄️ قاعدة بيانات الأطعمة'),
      h('p', { class: 'muted' }, `${state.foods.length} صنف محفوظ ${db.storageInfo.kind === 'cloud' ? 'في حسابك (مساحة خاصة بك وحدك، تتزامن بين أجهزتك)' : 'على هذا الجهاز'}.`),
      h('div', { class: 'row-actions wrap' },
        h('button', { class: 'btn', onclick: exportFoodsJSON }, '⬇️ تصدير (JSON)'),
        h('button', { class: 'btn', onclick: exportFoodsCSV }, '⬇️ تصدير (CSV / Excel)'),
        h('button', { class: 'btn', onclick: importFoods }, '⬆️ استيراد أطعمة'),
        h('button', { class: 'btn danger-ghost', onclick: resetFoods }, 'استعادة الأصناف الأصلية من الجداول'))),

    h('section', { class: 'card' },
      h('h2', {}, '💾 النسخ الاحتياطي'),
      h('p', { class: 'muted' }, 'نسخة كاملة تشمل الأطعمة والوجبات المحفوظة وسجل السكر والإعدادات. احفظها في الملفات أو iCloud لنقلها لجهاز آخر.'),
      h('div', { class: 'row-actions wrap' },
        h('button', { class: 'btn primary', onclick: exportBackup }, '⬇️ إنشاء نسخة احتياطية'),
        h('button', { class: 'btn', onclick: restoreBackup }, '⬆️ استعادة من نسخة احتياطية'))),

    h('section', { class: 'card' },
      h('h2', {}, '📱 التثبيت كتطبيق'),
      h('p', {}, 'على الآيفون/الآيباد: افتح الموقع في Safari ← زر المشاركة ← «إضافة إلى الشاشة الرئيسية».'),
      h('p', {}, 'على أندرويد/الكمبيوتر: من قائمة المتصفح اختر «تثبيت التطبيق».'),
      h('p', { class: 'muted small' }, db.storageInfo.kind === 'cloud'
        ? 'بياناتك محفوظة في مساحة خاصة بحسابك في Claude، ولا يستطيع أحد غيرك قراءتها أو تعديلها، وتظهر نفسها على الآيفون والآيباد.'
        : 'تُحفظ البيانات على هذا الجهاز وهذا المتصفح فقط.')));
}

function stamp() {
  return new Date().toISOString().slice(0, 10);
}

function exportFoodsJSON() {
  const data = { type: 'carb-calculator-foods', version: 1, exportedAt: new Date().toISOString(), foods: state.foods };
  return download(`أطعمة-${stamp()}.json`, JSON.stringify(data, null, 2));
}

const CSV_COLS = ['name', 'category', 'refQty', 'unit', 'carbs', 'altQty', 'altUnit', 'note', 'source', 'id'];
function exportFoodsCSV() {
  const esc = (v) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const rows = state.foods.map((f) => CSV_COLS.map((c) => esc(c === 'category' ? getCategory(f.category).name : f[c])).join(','));
  download(`أطعمة-${stamp()}.csv`, '﻿' + [CSV_COLS.join(','), ...rows].join('\n'), 'text/csv');
}

function parseCSV(text) {
  const rows = [];
  let row = [], cur = '', q = false;
  text = text.replace(/^﻿/, '');
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"' && text[i + 1] === '"') { cur += '"'; i++; } else if (ch === '"') q = false; else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cur); cur = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cur); rows.push(row); row = []; cur = '';
    } else cur += ch;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  const [head, ...body] = rows.filter((r) => r.some((c) => c.trim()));
  if (!head) return [];
  const keys = head.map((k) => k.trim());
  return body.map((r) => Object.fromEntries(keys.map((k, i) => [k, r[i] ?? ''])));
}

async function readFoodsFile(file) {
  const text = await file.text();
  if (file.name.toLowerCase().endsWith('.csv')) {
    return parseCSV(text).map((r) => ({ ...r, category: resolveCategory(r.category), refQty: parseNum(r.refQty), carbs: r.carbs === '' ? null : parseNum(r.carbs), altQty: r.altQty === '' ? null : parseNum(r.altQty) }));
  }
  const json = JSON.parse(text);
  const list = Array.isArray(json) ? json : json.foods;
  if (!Array.isArray(list)) throw new Error('لا يحتوي الملف على قائمة أطعمة');
  return list.map((r) => ({ ...r, category: resolveCategory(r.category) }));
}

async function importFoods() {
  const file = await pickFile('.json,.csv,application/json,text/csv');
  if (!file) return;
  let list;
  try {
    list = (await readFoodsFile(file)).filter((f) => String(f.name || '').trim());
  } catch (e) {
    toast(`تعذر قراءة الملف: ${e.message}`, 'error');
    return;
  }
  if (!list.length) { toast('الملف لا يحتوي على أصناف', 'error'); return; }

  let choice = null;
  await new Promise((resolve) => modal({
    title: 'استيراد الأطعمة',
    content: h('p', {}, `يحتوي الملف على ${list.length} صنف. كيف تريد الاستيراد؟`),
    actions: [
      { label: 'دمج مع الموجود', class: 'primary', onClick: () => { choice = 'merge'; } },
      { label: 'استبدال الكل', class: 'danger', onClick: () => { choice = 'replace'; } },
      { label: 'إلغاء', class: 'ghost' },
    ],
    onClose: resolve,
  }));
  if (!choice) return;

  if (choice === 'replace') {
    await db.foods.replaceAll(list);
  } else {
    // الدمج: تحديث الصنف المطابق (بالمعرّف أو الاسم والوحدة) وإضافة الجديد
    const merged = list.map((f) => {
      const match = state.foods.find((x) => (f.id && x.id === f.id) || (f.seedId && x.seedId === f.seedId)
        || (x.name === String(f.name).trim() && x.unit === String(f.unit || '').trim()));
      return match ? { ...match, ...f, id: match.id } : { ...f, id: f.id || db.uid() };
    });
    await db.foods.putMany(merged);
  }
  state.foods = await db.foods.all();
  sortFoods();
  toast(`تم استيراد ${list.length} صنف`);
  render();
}

async function resetFoods() {
  const ok = await confirmDialog('سيتم استبدال قاعدة الأطعمة الحالية بالأصناف الأصلية المستخرجة من الجداول، وستُفقد الأصناف المضافة والتعديلات. ينصح بأخذ نسخة احتياطية أولاً. متابعة؟', { okLabel: 'استعادة', danger: true });
  if (!ok) return;
  await db.restoreOriginalFoods();
  state.foods = await db.foods.all();
  sortFoods();
  toast('تمت استعادة الأصناف الأصلية');
  render();
}

async function exportBackup() {
  const data = {
    type: 'carb-calculator-backup', version: 1, exportedAt: new Date().toISOString(),
    foods: state.foods, meals: state.meals, logs: state.logs, settings: await db.settings.all(),
  };
  if (await download(`نسخة-احتياطية-حاسبة-الكربوهيدرات-${stamp()}.json`, JSON.stringify(data, null, 2))) toast('تم حفظ النسخة الاحتياطية');
}

async function restoreBackup() {
  const file = await pickFile('.json,application/json');
  if (!file) return;
  let data;
  try {
    data = JSON.parse(await file.text());
    if (data.type !== 'carb-calculator-backup' || !Array.isArray(data.foods)) throw new Error('ليس ملف نسخة احتياطية لهذا التطبيق');
  } catch (e) {
    toast(`تعذر قراءة الملف: ${e.message}`, 'error');
    return;
  }
  const ok = await confirmDialog(`استعادة النسخة الاحتياطية (${data.foods.length} صنف، ${(data.meals || []).length} وجبة، ${(data.logs || []).length} تسجيل)؟ ستُستبدل جميع البيانات الحالية.`, { okLabel: 'استعادة', danger: true });
  if (!ok) return;
  await db.foods.replaceAll(data.foods);
  await db.meals.replaceAll(data.meals || []);
  for (const s of data.settings || []) if (s.key !== 'logMonths') await db.settings.set(s.key, s.value);
  await db.logs.replaceAll(data.logs || []);
  await loadAll();
  toast('تمت استعادة النسخة الاحتياطية');
  render();
}

/* ───────────── التشغيل ───────────── */

async function init() {
  buildNav();
  try {
    clear($('#view'), h('div', { class: 'loading' }, 'جارِ تحميل بياناتك…'));
    await db.initStorage();
    await loadAll();
  } catch (e) {
    console.error(e);
    clear($('#view'), emptyState('⚠️', `تعذر تحميل البيانات: ${e?.message || 'خطأ غير معروف'}`,
      h('button', { class: 'btn primary', onclick: () => location.reload() }, 'إعادة المحاولة')));
    return;
  }
  if (window.claude && db.storageInfo.kind === 'local') {
    toast('لم يتوفر الحفظ في حسابك؛ تُحفظ البيانات على هذا الجهاز فقط', 'error');
  }
  db.requestPersistence();
  window.addEventListener('hashchange', route);
  route();
  document.body.classList.add('ready');

  // مزامنة عند العودة للتطبيق (مثلاً بعد التعديل من الآيباد)
  let lastSync = Date.now();
  document.addEventListener('visibilitychange', async () => {
    if (document.visibilityState !== 'visible' || db.storageInfo.kind !== 'cloud') return;
    if (Date.now() - lastSync < 15000 || document.querySelector('dialog[open]')) return;
    lastSync = Date.now();
    try {
      await loadAll();
      render();
    } catch { /* تجاهل؛ تبقى البيانات الحالية */ }
  });

  if ('serviceWorker' in navigator && !window.claude && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
}

init();
