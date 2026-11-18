// سجل السكر والوجبات: التاريخ واليوم والوقت، السكر قبل الوجبة، الوجبة، جرعة الإنسولين، السكر بعد ساعتين
import { h, clear, toast, modal, confirmDialog, download } from './ui.js';
import {
  fmt, parseNum, roundTo, formatDose, insulinDose, todayStr, nowTimeStr, weekdayName, formatDateAr,
  formatTime12, dueTime, logsToCSV, isValidDateStr, MEAL_TYPES,
} from './calc.js';
import * as db from './db.js';

const AFTER_MINUTES = 120;
const ui = { period: '30' }; // فترة العرض: 7 أو 30 يوماً أو all

/** نوع الوجبة المقترح حسب الوقت */
function guessMealType(time) {
  const hr = Number(String(time).split(':')[0]);
  if (hr >= 5 && hr < 11) return 'فطور';
  if (hr >= 11 && hr < 17) return 'غداء';
  if (hr >= 17 && hr < 23) return 'عشاء';
  return 'وجبة خفيفة';
}

/** نسخة مختصرة من وجبة (أصناف الحاسبة أو وجبة محفوظة) تُخزَّن داخل التسجيل */
export function mealFromItems(ctx, name, items) {
  return {
    name: name || '',
    items: items.map((it) => {
      const food = ctx.itemFood(it);
      return { name: food.name, qty: ctx.qtyLabel(it, food), carbs: roundTo(ctx.itemCarbs(it), 1) };
    }),
    totalCarbs: ctx.mealTotal(items),
  };
}

function sortedLogs(state) {
  return [...state.logs].sort((a, b) => `${b.date} ${b.time}`.localeCompare(`${a.date} ${a.time}`));
}

/** التسجيلات التي حان (أو يقترب) موعد قياسها بعد ساعتين ولم يُدخل بعد */
function pendingAfter(state, now = new Date()) {
  return state.logs.filter((e) => {
    if (e.bgAfter != null && e.bgAfter !== '') return false;
    const due = dueTime(e, AFTER_MINUTES);
    const diffH = (now - due) / 3600000;
    return diffH > -2.5 && diffH < 12; // من بعد الوجبة بقليل حتى 12 ساعة بعد الموعد
  }).sort((a, b) => dueTime(a) - dueTime(b));
}

function relTime(due, now = new Date()) {
  const min = Math.round((due - now) / 60000);
  if (Math.abs(min) < 1) return 'الآن';
  const abs = Math.abs(min);
  const txt = abs < 60 ? `${abs} دقيقة` : `${Math.floor(abs / 60)} س ${abs % 60 ? `${abs % 60} د` : ''}`.trim();
  return min > 0 ? `بعد ${txt}` : `منذ ${txt}`;
}

/* ───────────── صفحة السجل ───────────── */

export function renderLog(root, ctx) {
  const { state } = ctx;
  const pending = pendingAfter(state);
  const all = sortedLogs(state);
  const from = ui.period === 'all' ? '' : todayStr(new Date(Date.now() - (Number(ui.period) - 1) * 86400000));
  const list = all.filter((e) => !from || e.date >= from);

  // تجميع حسب التاريخ
  const groups = [];
  for (const e of list) {
    const g = groups[groups.length - 1];
    if (g && g.date === e.date) g.items.push(e); else groups.push({ date: e.date, items: [e] });
  }

  clear(root,
    h('div', { class: 'page-head' },
      h('h1', {}, '📝 سجل السكر والوجبات'),
      h('button', { class: 'btn primary', id: 'log-new', onclick: () => openLogForm(ctx) }, '➕ تسجيل جديد')),

    pending.length > 0 && h('section', { class: 'card pending' },
      h('h2', {}, '⏰ قياس بعد ساعتين'),
      h('ul', { class: 'pending-list' }, pending.map((e) => {
        const due = dueTime(e, AFTER_MINUTES);
        const overdue = due <= new Date();
        return h('li', {},
          h('div', {},
            h('strong', {}, `${e.mealType || 'وجبة'} ${formatTime12(e.time)}`),
            h('div', { class: overdue ? 'due now' : 'due' }, `الموعد ${formatTime12(`${due.getHours()}:${String(due.getMinutes()).padStart(2, '0')}`)} — ${relTime(due)}`)),
          h('button', { class: 'btn small primary', onclick: () => quickAfter(ctx, e) }, 'إدخال القياس'));
      }))),

    h('div', { class: 'log-toolbar' },
      h('div', { class: 'segmented', role: 'radiogroup', 'aria-label': 'فترة العرض' },
        [['7', 'آخر 7 أيام'], ['30', 'آخر 30 يوماً'], ['all', 'الكل']].map(([v, label]) => h('button', {
          type: 'button', role: 'radio', class: ui.period === v ? 'active' : '', 'aria-checked': String(ui.period === v),
          onclick: () => { ui.period = v; renderLog(root, ctx); },
        }, label))),
      all.length > 0 && h('button', { class: 'btn small', onclick: () => exportLog(state) }, '⬇️ تصدير (Excel)')),

    !list.length
      ? ctx.emptyState('📝', all.length
        ? 'لا توجد تسجيلات في هذه الفترة.'
        : 'لا توجد تسجيلات بعد. سجّل قياس السكر قبل الوجبة، والوجبة، والجرعة، ثم القياس بعد ساعتين.',
      h('button', { class: 'btn primary', onclick: () => openLogForm(ctx) }, '➕ أول تسجيل'))
      : h('div', { class: 'log-days' }, groups.map((g) =>
        h('section', { class: 'log-day' },
          h('h2', { class: 'day-head' }, formatDateAr(g.date),
            g.date === todayStr() && h('span', { class: 'badge carbs' }, 'اليوم')),
          g.items.map((e) => logCard(ctx, e))))));
}

function logCard(ctx, e) {
  const unit = e.unit || 'mg/dL';
  const has = (v) => v != null && v !== '';
  const diff = has(e.bgBefore) && has(e.bgAfter) ? Number(e.bgAfter) - Number(e.bgBefore) : null;
  const meal = e.meal;
  return h('article', { class: 'card log-entry' },
    h('div', { class: 'log-head' },
      h('div', { class: 'log-time' }, h('strong', {}, formatTime12(e.time)), e.mealType && h('span', { class: 'chip small static' }, e.mealType)),
      h('div', { class: 'row-btns' },
        h('button', { class: 'icon-btn', title: 'تعديل', 'aria-label': 'تعديل التسجيل', onclick: () => openLogForm(ctx, e) }, '✏️'),
        h('button', { class: 'icon-btn', title: 'حذف', 'aria-label': 'حذف التسجيل', onclick: () => deleteLog(ctx, e) }, '🗑️'))),
    h('div', { class: 'metrics' },
      metric('قبل الوجبة', has(e.bgBefore) ? fmt(Number(e.bgBefore), 1) : '—', unit),
      metric('جرعة الإنسولين', has(e.dose) ? fmt(Number(e.dose), 2) : '—', 'وحدة'),
      metric('بعد ساعتين', has(e.bgAfter) ? fmt(Number(e.bgAfter), 1) : '—', unit,
        diff != null ? `${diff > 0 ? '+' : ''}${fmt(diff, 1)}` : (!has(e.bgAfter) ? 'لم يُسجَّل' : null))),
    meal && (meal.name || meal.items?.length || meal.totalCarbs != null) && h('details', { class: 'log-meal' },
      h('summary', {},
        h('span', {}, `🍽️ ${meal.name || 'الوجبة'}`),
        meal.totalCarbs != null && h('span', { class: 'badge carbs' }, `${fmt(Number(meal.totalCarbs), 1)} جم كربوهيدرات`)),
      meal.items?.length > 0 && h('ul', { class: 'meal-items' }, meal.items.map((i) =>
        h('li', {}, h('span', {}, i.name), h('span', { class: 'muted' }, i.qty), h('span', {}, `${fmt(Number(i.carbs), 1)} جم`))))),
    e.note && h('p', { class: 'log-note' }, e.note));
}

function metric(label, value, unit, sub) {
  return h('div', { class: 'metric' },
    h('span', { class: 'metric-label' }, label),
    h('span', { class: 'metric-value' }, value, value !== '—' && h('small', {}, ` ${unit}`)),
    sub && h('span', { class: 'metric-sub' }, sub));
}

/* ───────────── نموذج التسجيل ───────────── */

/**
 * prefill: تسجيل موجود للتعديل (له id)، أو بيانات أولية { meal } من الحاسبة/الوجبات المحفوظة
 */
export function openLogForm(ctx, prefill = {}) {
  const { state } = ctx;
  const isEdit = !!prefill.id;
  const now = new Date();
  const e = {
    date: todayStr(now), time: nowTimeStr(now), mealType: '', bgBefore: '', dose: '', bgAfter: '',
    unit: state.glucoseUnit, note: '', meal: null, ...prefill,
  };
  if (!e.mealType) e.mealType = guessMealType(e.time);
  let meal = e.meal ? JSON.parse(JSON.stringify(e.meal)) : null;
  let mealType = e.mealType;
  const unit = e.unit || state.glucoseUnit;
  const num = (v) => (v == null || v === '' ? '' : String(v));

  const dateInput = h('input', { class: 'input', type: 'date', id: 'log-date', value: e.date, required: true });
  const dayLabel = h('span', { class: 'day-label', id: 'log-day' });
  const timeInput = h('input', { class: 'input', type: 'time', id: 'log-time', value: e.time, required: true });
  const bgBefore = h('input', { class: 'input', id: 'log-before', inputmode: 'decimal', value: num(e.bgBefore), placeholder: unit === 'mmol/L' ? 'مثال: 6.5' : 'مثال: 120' });
  const dose = h('input', { class: 'input', id: 'log-dose', inputmode: 'decimal', value: num(e.dose), placeholder: 'الجرعة التي أخذتها' });
  const bgAfter = h('input', { class: 'input', id: 'log-after', inputmode: 'decimal', value: num(e.bgAfter), placeholder: 'يمكن إضافته لاحقاً' });
  const note = h('input', { class: 'input', id: 'log-note', value: e.note || '', placeholder: 'اختياري — مثال: رياضة، مرض…' });
  const dueLabel = h('small', { class: 'muted', id: 'log-due' });
  const doseHint = h('div', { class: 'dose-hint' });
  const errorsBox = h('div', { class: 'form-errors', role: 'alert' });

  const updateDay = () => {
    dayLabel.textContent = weekdayName(dateInput.value) || '—';
    if (isValidDateStr(dateInput.value) && /^\d{1,2}:\d{2}$/.test(timeInput.value)) {
      const due = dueTime({ date: dateInput.value, time: timeInput.value }, AFTER_MINUTES);
      dueLabel.textContent = `موعد القياس: ${formatTime12(`${due.getHours()}:${String(due.getMinutes()).padStart(2, '0')}`)}${todayStr(due) !== dateInput.value ? ' (اليوم التالي)' : ''}`;
    } else dueLabel.textContent = '';
  };
  dateInput.addEventListener('input', updateDay);
  timeInput.addEventListener('input', updateDay);

  const typeChips = h('div', { class: 'chips wrap', role: 'radiogroup', 'aria-label': 'نوع الوجبة' },
    MEAL_TYPES.map((t) => h('button', {
      type: 'button', role: 'radio', class: `chip${t === mealType ? ' active' : ''}`,
      onclick: (ev) => {
        mealType = mealType === t ? '' : t;
        typeChips.querySelectorAll('.chip').forEach((b) => b.classList.toggle('active', b.textContent === mealType));
        ev.preventDefault();
      },
    }, t)));

  /* ── اختيار الوجبة ── */
  const mealBox = h('div', { class: 'meal-pick' });
  const sources = h('div', { class: 'row-actions wrap small-gap' });
  const savedSelect = h('select', { class: 'input', id: 'log-saved-meal', hidden: true, 'aria-label': 'اختر وجبة محفوظة' },
    h('option', { value: '' }, '— اختر وجبة محفوظة —'),
    [...state.meals].sort((a, b) => a.name.localeCompare(b.name, 'ar')).map((m) => h('option', { value: m.id }, `${m.name} (${fmt(ctx.mealTotal(m.items), 1)} جم)`)));
  const manualName = h('input', { class: 'input', id: 'log-meal-name', placeholder: 'وصف الوجبة (مثال: كبسة دجاج)' });
  const manualCarbs = h('input', { class: 'input', id: 'log-meal-carbs', inputmode: 'decimal', placeholder: 'الكربوهيدرات بالجرام (اختياري)' });
  const manualBox = h('div', { class: 'grid-2', hidden: true }, manualName, manualCarbs);

  savedSelect.addEventListener('change', () => {
    const m = state.meals.find((x) => x.id === savedSelect.value);
    meal = m ? mealFromItems(ctx, m.name, m.items) : null;
    renderMeal();
  });
  const syncManual = () => {
    const c = parseNum(manualCarbs.value);
    meal = { name: manualName.value.trim(), items: [], totalCarbs: c >= 0 ? c : null };
    renderDoseHint();
  };
  manualName.addEventListener('input', syncManual);
  manualCarbs.addEventListener('input', syncManual);

  function setSource(src) {
    savedSelect.hidden = src !== 'saved';
    manualBox.hidden = src !== 'manual';
    if (src === 'current') meal = mealFromItems(ctx, ctx.defaultMealName(), state.current.items);
    if (src === 'saved') { savedSelect.value = ''; meal = null; }
    if (src === 'manual') {
      manualName.value = meal?.items?.length ? '' : (meal?.name || '');
      manualCarbs.value = meal && !meal.items?.length && meal.totalCarbs != null ? String(meal.totalCarbs) : '';
      syncManual();
    }
    if (src === 'none') meal = null;
    sources.querySelectorAll('.btn').forEach((b) => b.classList.toggle('active', b.dataset.src === src));
    renderMeal();
  }

  clear(sources,
    state.current.items.length > 0 && h('button', { type: 'button', class: 'btn small', dataset: { src: 'current' }, onclick: () => setSource('current') },
      `🧮 الوجبة الحالية (${fmt(ctx.mealTotal(state.current.items), 1)} جم)`),
    state.meals.length > 0 && h('button', { type: 'button', class: 'btn small', dataset: { src: 'saved' }, onclick: () => setSource('saved') }, '📋 من المحفوظة'),
    h('button', { type: 'button', class: 'btn small', dataset: { src: 'manual' }, onclick: () => setSource('manual') }, '✍️ كتابة يدوية'),
    meal && h('button', { type: 'button', class: 'btn small ghost', dataset: { src: 'none' }, onclick: () => setSource('none') }, 'بدون وجبة'));

  function renderMeal() {
    if (!meal || (!meal.name && !meal.items?.length && meal.totalCarbs == null)) {
      clear(mealBox, manualBox.hidden ? h('p', { class: 'muted small' }, 'لم تُحدد وجبة.') : null);
    } else if (manualBox.hidden) {
      clear(mealBox,
        h('div', { class: 'meal-chosen' },
          h('div', { class: 'meal-chosen-head' },
            h('strong', {}, meal.name || 'الوجبة'),
            meal.totalCarbs != null && h('span', { class: 'badge carbs' }, `${fmt(Number(meal.totalCarbs), 1)} جم كربوهيدرات`)),
          meal.items?.length > 0 && h('ul', { class: 'meal-items' }, meal.items.map((i) =>
            h('li', {}, h('span', {}, i.name), h('span', { class: 'muted' }, i.qty), h('span', {}, `${fmt(Number(i.carbs), 1)} جم`))))));
    } else clear(mealBox);
    renderDoseHint();
  }

  // الناتج الحسابي يظهر كاقتراح فقط ولا يُعبّأ تلقائياً
  function renderDoseHint() {
    const carbs = Number(meal?.totalCarbs);
    if (!(carbs > 0)) { clear(doseHint); return; }
    const calc = formatDose(insulinDose(carbs, state.ratio));
    clear(doseHint,
      h('span', { class: 'muted small' }, `الناتج الحسابي للوجبة: ${fmt(carbs, 1)} ÷ ${fmt(state.ratio, 2)} = ${calc}`),
      h('button', { type: 'button', class: 'link-btn', onclick: () => { dose.value = calc; } }, 'استخدامه'));
  }

  const content = h('form', { class: 'log-form', onsubmit: (ev) => ev.preventDefault() },
    h('div', { class: 'grid-2' },
      h('label', { class: 'field' }, h('span', {}, '📅 التاريخ'), dateInput, h('small', { class: 'muted' }, 'اليوم: ', dayLabel)),
      h('label', { class: 'field' }, h('span', {}, '🕐 وقت الوجبة'), timeInput, dueLabel)),
    h('div', { class: 'field' }, h('span', {}, 'نوع الوجبة'), typeChips),
    h('label', { class: 'field' }, h('span', {}, `🩸 قياس السكر قبل الوجبة (${unit})`), bgBefore),
    h('div', { class: 'field' }, h('span', {}, '🍽️ الوجبة'), sources, savedSelect, manualBox, mealBox),
    h('label', { class: 'field' }, h('span', {}, '💉 جرعة الإنسولين التي أخذتها (وحدة)'), dose, doseHint),
    h('label', { class: 'field' }, h('span', {}, `🩸 قياس السكر بعد ساعتين من الوجبة (${unit})`), bgAfter),
    h('label', { class: 'field' }, h('span', {}, '📝 ملاحظات'), note),
    errorsBox);

  modal({
    title: isEdit ? 'تعديل التسجيل' : 'تسجيل جديد',
    content,
    wide: true,
    actions: [
      { label: isEdit ? 'حفظ التعديلات' : 'حفظ في السجل', class: 'primary', onClick: async () => {
        const errors = [];
        if (!isValidDateStr(dateInput.value)) errors.push('اختر التاريخ');
        if (!/^\d{1,2}:\d{2}$/.test(timeInput.value)) errors.push('اختر الوقت');
        const read = (input, label) => {
          const raw = input.value.trim();
          if (!raw) return null;
          const v = parseNum(raw);
          if (!(v > 0) || !Number.isFinite(v)) { errors.push(`${label}: أدخل رقماً أكبر من صفر`); return null; }
          return v;
        };
        const vBefore = read(bgBefore, 'قياس السكر قبل الوجبة');
        const vDose = dose.value.trim() === '0' ? 0 : read(dose, 'جرعة الإنسولين');
        const vAfter = read(bgAfter, 'قياس السكر بعد ساعتين');
        if (!manualBox.hidden && manualCarbs.value.trim() && !(parseNum(manualCarbs.value) >= 0)) errors.push('كربوهيدرات الوجبة: أدخل رقماً صحيحاً');
        if (errors.length) {
          clear(errorsBox, h('ul', {}, errors.map((x) => h('li', {}, x))));
          return false;
        }
        const entry = {
          id: e.id || db.uid(),
          date: dateInput.value,
          time: timeInput.value,
          mealType,
          bgBefore: vBefore,
          dose: vDose,
          bgAfter: vAfter,
          unit,
          meal: meal && (meal.name || meal.items?.length || meal.totalCarbs != null) ? meal : null,
          note: note.value.trim(),
          createdAt: e.createdAt || Date.now(),
        };
        const saved = await db.logs.save(entry);
        const i = state.logs.findIndex((x) => x.id === saved.id);
        if (i >= 0) state.logs[i] = saved; else state.logs.push(saved);
        toast(isEdit ? 'تم حفظ التعديلات' : 'تم الحفظ في السجل');
        if (state.view === 'log') ctx.render(); else location.hash = '#log';
      } },
      { label: 'إلغاء', class: 'ghost' },
    ],
  });

  updateDay();
  // مصدر الوجبة عند الفتح: وجبة جاهزة بأصناف ← عرضها، وجبة يدوية ← حقول الكتابة،
  // بدون وجبة ← الوجبة الحالية في الحاسبة إن وُجدت، وإلا الكتابة اليدوية
  if (meal?.items?.length) renderMeal();
  else if (meal) setSource('manual');
  else if (!isEdit && state.current.items.length) setSource('current');
  else setSource('manual');
}

/** إدخال سريع لقياس ما بعد ساعتين */
function quickAfter(ctx, e) {
  const input = h('input', { class: 'input qty-input', inputmode: 'decimal', id: 'quick-after', 'aria-label': 'قياس السكر بعد ساعتين' });
  const err = h('div', { class: 'form-errors', role: 'alert' });
  const save = async () => {
    const v = parseNum(input.value);
    if (!(v > 0)) { clear(err, h('ul', {}, h('li', {}, 'أدخل رقماً أكبر من صفر'))); return false; }
    const saved = await db.logs.save({ ...e, bgAfter: v });
    const i = ctx.state.logs.findIndex((x) => x.id === e.id);
    ctx.state.logs[i] = saved;
    toast('تم حفظ القياس');
    ctx.render();
  };
  const dlg = modal({
    title: 'قياس السكر بعد ساعتين',
    content: h('div', {},
      h('p', { class: 'muted' }, `${e.mealType || 'وجبة'} — ${formatDateAr(e.date)} ${formatTime12(e.time)}`),
      h('label', { class: 'field' }, h('span', {}, `القياس (${e.unit || 'mg/dL'})`), input),
      err),
    actions: [{ label: 'حفظ', class: 'primary', onClick: save }, { label: 'إلغاء', class: 'ghost' }],
  });
  input.addEventListener('keydown', async (ev) => { if (ev.key === 'Enter' && (await save()) !== false) dlg.close(); });
  setTimeout(() => input.focus(), 50);
}

async function deleteLog(ctx, e) {
  const ok = await confirmDialog(`حذف تسجيل ${formatDateAr(e.date)} ${formatTime12(e.time)}؟`, { okLabel: 'حذف', danger: true });
  if (!ok) return;
  await db.logs.remove(e.id);
  ctx.state.logs = ctx.state.logs.filter((x) => x.id !== e.id);
  toast('تم حذف التسجيل');
  ctx.render();
}

async function exportLog(state) {
  const stamp = todayStr();
  if (await download(`سجل-السكر-${stamp}.csv`, logsToCSV(state.logs), 'text/csv')) toast('تم تصدير السجل');
}

