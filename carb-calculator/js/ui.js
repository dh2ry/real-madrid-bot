// مكونات واجهة صغيرة قابلة لإعادة الاستخدام

/** إنشاء عنصر: h('button', {class:'btn', onclick}, 'نص', child) */
export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
    else if (k === 'class') el.className = v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (k in el && typeof v !== 'string') el[k] = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  append(el, children);
  return el;
}

function append(el, children) {
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
}

export function clear(el, ...children) {
  el.replaceChildren();
  append(el, children);
  return el;
}

let toastTimer;
export function toast(msg, type = 'ok') {
  let t = document.getElementById('toast');
  if (!t) {
    t = h('div', { id: 'toast', role: 'status', 'aria-live': 'polite' });
    document.body.append(t);
  }
  t.textContent = msg;
  t.className = `toast show ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2600);
}

/**
 * نافذة منبثقة. تُرجع { el, body, close }.
 * actions: [{label, class, onClick(close) → false لإبقاء النافذة مفتوحة}]
 */
export function modal({ title, content, actions = [], onClose, wide = false }) {
  const dlg = h('dialog', { class: `modal${wide ? ' wide' : ''}` });
  const close = () => {
    dlg.close();
  };
  dlg.addEventListener('close', () => {
    dlg.remove();
    onClose?.();
  });
  dlg.addEventListener('click', (e) => {
    if (e.target === dlg) close();
  });
  const body = h('div', { class: 'modal-body' }, content);
  const footer = h('div', { class: 'modal-actions' },
    actions.map((a) => h('button', {
      type: 'button',
      class: `btn ${a.class || ''}`,
      onclick: async () => {
        const r = await a.onClick?.(close);
        if (r !== false) close();
      },
    }, a.label)));
  dlg.append(
    h('div', { class: 'modal-head' },
      h('h2', {}, title),
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'إغلاق', onclick: close }, '✕')),
    body,
    actions.length ? footer : null,
  );
  document.body.append(dlg);
  dlg.showModal();
  return { el: dlg, body, close };
}

export function confirmDialog(message, { okLabel = 'تأكيد', danger = false } = {}) {
  return new Promise((resolve) => {
    let ok = false;
    modal({
      title: 'تأكيد',
      content: h('p', { class: 'confirm-text' }, message),
      actions: [
        { label: okLabel, class: danger ? 'danger' : 'primary', onClick: () => { ok = true; } },
        { label: 'إلغاء', class: 'ghost' },
      ],
      onClose: () => resolve(ok),
    });
  });
}

export function promptDialog(title, { label = '', value = '', okLabel = 'حفظ' } = {}) {
  return new Promise((resolve) => {
    let result = null;
    const input = h('input', { class: 'input', value, 'aria-label': label || title });
    const { close } = modal({
      title,
      content: h('label', { class: 'field' }, label && h('span', {}, label), input),
      actions: [
        { label: okLabel, class: 'primary', onClick: () => {
          if (!input.value.trim()) { input.focus(); return false; }
          result = input.value.trim();
        } },
        { label: 'إلغاء', class: 'ghost' },
      ],
      onClose: () => resolve(result),
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && input.value.trim()) { result = input.value.trim(); close(); }
    });
    setTimeout(() => input.select(), 50);
  });
}

export function download(filename, text, type = 'application/json') {
  const blob = new Blob([text], { type: `${type};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const a = h('a', { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

export function pickFile(accept) {
  return new Promise((resolve) => {
    const input = h('input', { type: 'file', accept, style: { display: 'none' } });
    input.addEventListener('change', () => {
      resolve(input.files[0] || null);
      input.remove();
    });
    document.body.append(input);
    input.click();
  });
}

/** تصغير صورة إلى مربع صغير وحفظها كنص (data URL) */
export function resizeImage(file, max = 240) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const scale = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * scale);
      c.height = Math.round(img.height * scale);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', 0.82));
    };
    img.onerror = reject;
    img.src = url;
  });
}
