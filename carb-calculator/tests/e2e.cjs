// اختبار شامل للواجهة في متصفح حقيقي. يتطلب تشغيل الخادم: npm start
// الاستخدام: node tests/e2e.cjs [url] [مجلد_الصور]
const { chromium, devices } = require('playwright');
const assert = require('node:assert/strict');

const URL = process.argv[2] || 'http://localhost:8080/';
const SHOTS = process.argv[3];

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ ...devices['iPhone 13'], locale: 'ar' });
  // MOCK_CLAUDE=1 يحاكي قاعدة بيانات Claude لاختبار الصفحة المنشورة
  if (process.env.MOCK_CLAUDE) await ctx.addInitScript({ path: require('node:path').join(__dirname, 'claude-mock.js') });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  const shot = (n) => SHOTS && page.screenshot({ path: `${SHOTS}/${n}.png`, fullPage: false });
  const step = (m) => console.log('✓', m);
  const totalIs = (t) => page.waitForFunction((t) => document.querySelector('#meal-total')?.textContent.trim() === t, t, { timeout: 5000 });

  await page.goto(URL);
  await page.waitForSelector('.cat-card');
  assert.equal(await page.locator('.cat-card').count(), 10);
  await shot('01-home');
  step('الصفحة الرئيسية تعرض 10 تصنيفات');

  // إضافة صنف عبر البحث مع كمية مختلفة
  const addFood = async (query, qty, mode) => {
    await page.fill('.search-bar input', query);
    await page.locator('.food-row').first().click();
    await page.waitForSelector('dialog .qty-input');
    if (mode) await page.locator('.segmented button', { hasText: mode }).click();
    if (qty != null) await page.fill('.qty-input', String(qty));
    await page.locator('dialog .btn.primary').click();
    await page.waitForSelector('dialog', { state: 'detached' });
  };

  await addFood('لبناني', null); // 1 حبة = 45
  await page.fill('.search-bar input', 'ارز حجم');
  await page.locator('.food-row').first().click();
  await page.fill('.qty-input', '1');
  await shot('02-qty-dialog');
  await page.locator('dialog .btn.primary').click();
  await page.waitForSelector('dialog', { state: 'detached' });
  await addFood('حليب كامل', 200, 'مل'); // 200 مل = 9.6
  await addFood('ماري', 2); // 2 حبة = 7.5
  const total = await page.textContent('#meal-total');
  assert.equal(total.trim(), '107.1 جم'); // 45 + 45 + 9.6 + 7.5
  assert.match(await page.textContent('#dose-value'), /^4\.28/); // 107.1 ÷ 25 = 4.284
  assert.match(await page.textContent('#meal-fab'), /107\.1.*4\.28/);
  await page.fill('.search-bar input', '');
  await shot('02b-fab');
  step('إضافة 4 أصناف بوحدات مختلفة: الإجمالي 107.1 جم والجرعة 4.28 (والشريط العائم محدّث)');

  // تعديل كمية الحليب إلى كوب كامل
  await page.locator('.meal-table tbody tr', { hasText: 'حليب' }).locator('button[title="تعديل الكمية"]').click();
  await page.fill('.qty-input', '250');
  await page.locator('dialog .btn.primary').click();
  await page.waitForSelector('dialog', { state: 'detached' });
  await totalIs('109.5 جم');
  step('تعديل الكمية يحدّث الإجمالي');

  // حذف البسكوت
  await page.locator('.meal-table tbody tr', { hasText: 'ماري' }).locator('button[title="حذف"]').click();
  await totalIs('102 جم');
  assert.match(await page.textContent('#dose-value'), /^4\.08/);
  step('الحذف يحدّث الإجمالي والجرعة (102 ÷ 25 = 4.08)');
  await page.fill('.search-bar input', '');
  await page.locator('#meal-card').scrollIntoViewIfNeeded();
  await shot('03-meal');
  await page.locator('#insulin-card').scrollIntoViewIfNeeded();
  await shot('04-insulin');

  // الحفظ يبقى بعد إعادة التحميل
  await page.reload();
  await page.waitForSelector('#meal-total');
  assert.equal((await page.textContent('#meal-total')).trim(), '102 جم');
  step('الوجبة الحالية تبقى بعد تحديث الصفحة');

  // حفظ الوجبة
  await page.click('text=💾 حفظ الوجبة');
  await page.fill('dialog input', 'غداء تجريبي');
  await page.locator('dialog .btn.primary').click();
  await page.waitForSelector('.banner'); // بعد الحفظ تصبح الوجبة في وضع التعديل
  await page.goto(URL + '#meals');
  await page.waitForSelector('.meal-saved');
  assert.match(await page.textContent('.meal-saved'), /غداء تجريبي/);
  assert.match(await page.textContent('.meal-total'), /102/);
  await shot('05-meals');
  step('حفظ الوجبة وعرضها في السجل مع الإجمالي');

  // تعديل الوجبة المحفوظة
  await page.click('text=✏️ تعديل');
  await page.waitForSelector('.banner');
  await addFood('تمر', 3);
  await page.click('text=💾 تحديث الوجبة المحفوظة');
  await page.waitForSelector('.toast.show');
  await page.goto(URL + '#meals');
  assert.match(await page.textContent('.meal-total'), /117/);
  step('تعديل الوجبة المحفوظة (+ تمر 15 = 117)');

  // تغيير المعامل
  await page.goto(URL + '#setup');
  await page.fill('.ratio-input', '20');
  await page.click('.ratio-row .btn.primary');
  await page.waitForSelector('.toast.show');
  await page.goto(URL + '#calc');
  assert.match(await page.textContent('#dose-value'), /^5\.85/); // 117 ÷ 20
  step('تغيير المعامل إلى 20: 117 ÷ 20 = 5.85');
  await page.goto(URL + '#setup');
  await shot('06-settings');
  await page.click('text=استعادة الافتراضي (25)');
  await page.waitForFunction(() => document.querySelector('.ratio-input')?.value === '25');
  await page.goto(URL + '#calc');
  assert.match(await page.textContent('#dose-value'), /^4\.68/);
  step('استعادة المعامل الافتراضي 25: 117 ÷ 25 = 4.68');

  // إدارة الأطعمة: إضافة ثم تعديل ثم حذف
  await page.goto(URL + '#foods');
  await page.click('text=➕ إضافة صنف');
  const form = page.locator('dialog .food-form');
  await form.locator('input').nth(0).fill('صنف اختبار');
  await form.locator('select').selectOption('grains');
  await form.locator('input').nth(1).fill('100');
  await form.locator('input').nth(2).fill('جرام');
  await form.locator('input').nth(3).fill('30');
  await shot('07-food-form');
  await page.locator('dialog .btn.primary').click();
  await page.waitForSelector('dialog', { state: 'detached' });
  await page.waitForSelector('.toast.show');
  await page.fill('.filters input', 'صنف اختبار');
  await page.waitForFunction(() => document.querySelectorAll('#manage-list .food-row').length === 1);
  await page.click('#manage-list button[title="تعديل"]');
  await form.locator('input').nth(3).fill('40');
  await page.locator('dialog .btn.primary').click();
  await page.waitForSelector('dialog', { state: 'detached' });
  await page.waitForFunction(() => /40 جم/.test(document.querySelector('#manage-list')?.textContent || ''));
  step('إضافة صنف وتعديل كربوهيدراته');

  await page.goto(URL + '#calc');
  await addFood('صنف اختبار', 150);
  await page.waitForSelector('#meal-total');
  assert.ok((await page.textContent('#meal-card')).includes('60 جم')); // 150 ÷ 100 × 40
  step('التعديل ينعكس مباشرة على الحساب (150 جم → 60 جم)');

  await page.goto(URL + '#foods');
  await page.fill('.filters input', 'صنف اختبار');
  await page.waitForFunction(() => document.querySelectorAll('#manage-list .food-row').length === 1);
  await page.click('#manage-list button[title="حذف"]');
  await page.locator('dialog .btn.danger').click();
  await page.waitForFunction(() => document.querySelectorAll('#manage-list .food-row').length === 0);
  step('حذف الصنف');

  // الأصناف الناقصة
  await page.goto(URL + '#calc');
  await page.fill('.search-bar input', 'تين مجفف');
  await page.locator('.food-row').first().click();
  assert.match(await page.textContent('dialog'), /ناقصة/);
  step('الأصناف الناقصة البيانات لا تُضاف قبل إكمالها');
  await page.keyboard.press('Escape');

  await page.goto(URL + '#foods');
  await page.fill('.filters input', '');
  await page.waitForSelector('#manage-list .food-row');
  await shot('08-manage');
  await page.goto(URL + '#calc');
  await page.fill('.search-bar input', '');
  await page.click('.cat-card:nth-child(4)');
  await shot('09-category');

  // سطح المكتب
  const desk = await browser.newPage({ viewport: { width: 1280, height: 860 } });
  await desk.goto(URL);
  await desk.waitForSelector('.cat-card');
  if (SHOTS) await desk.screenshot({ path: `${SHOTS}/10-desktop.png` });
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
  assert.equal(overflow, false, 'تمرير أفقي على الجوال');
  step('لا يوجد تمرير أفقي على الجوال');

  if (process.env.MOCK_CLAUDE) {
    const stored = await page.evaluate(() => Object.keys(JSON.parse(localStorage.getItem('__mock_db__') || '{}')));
    assert.ok(stored.length > 120, 'لم تُحفظ البيانات في قاعدة Claude');
    assert.ok(stored.every((k) => k.startsWith('data/users/viewer-123/app/')), 'بيانات خارج المساحة الخاصة');
    await page.goto(URL + '#setup');
    await page.click('text=⬇️ إنشاء نسخة احتياطية');
    await page.waitForFunction(() => window.__lastDownload);
    step(`الحفظ في مساحة المستخدم الخاصة فقط (${stored.length} مستند) والتنزيل عبر Claude`);
  }
  assert.deepEqual(errors, [], `أخطاء في المتصفح: ${errors.join(' | ')}`);
  step('لا أخطاء في وحدة التحكم');
  await browser.close();
  console.log('\nكل اختبارات الواجهة نجحت ✅');
})().catch((e) => { console.error('✗', e.message); process.exit(1); });
