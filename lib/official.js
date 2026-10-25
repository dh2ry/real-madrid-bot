// أخبار الموقع الرسمي لريال مدريد (realmadrid.com) — الفريق الأول فقط
import { config } from './config.js';

const BASE = 'https://www.realmadrid.com';
const opt = (k, d) => config.official?.[k] ?? d;
const decode = (s = '') => s
  .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, '&')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ')
  .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(n));
const strip = (s = '') => decode(s.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, '').replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();

async function get(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(20000), headers: { 'Accept-Language': 'es-ES,es;q=0.9' } });
  if (!res.ok) throw new Error(`${res.status}`);
  return res.text();
}

// تاريخ الخبر من آخر الرابط (…-25-10-2026)
function slugDate(url) {
  const m = url.match(/-(\d{2})-(\d{2})-(\d{4})$/);
  return m ? Date.UTC(+m[3], +m[2] - 1, +m[1], 12) : null;
}

async function listLinks() {
  const sections = opt('sections', ['primer-equipo']);
  const skip = opt('skipCategories', ['ruedas-de-prensa']);
  const html = await get(`${BASE}/es-ES/noticias/futbol`);
  const links = new Set();
  for (const [, path] of html.matchAll(/href="(\/es-ES\/noticias\/futbol\/[^"?#]+)"/g)) {
    const parts = path.split('/'); // ['', 'es-ES', 'noticias', 'futbol', section, category, slug]
    if (parts.length < 7) continue;
    if (!sections.includes(parts[4]) || skip.includes(parts[5])) continue;
    links.add(BASE + path);
  }
  return [...links];
}

async function readArticle(url) {
  const html = await get(url);
  const meta = (p) => decode(html.match(new RegExp(`<meta[^>]+(?:property|name)="${p}"[^>]+content="([^"]*)"`, 'i'))?.[1]
    || html.match(new RegExp(`<meta[^>]+content="([^"]*)"[^>]+(?:property|name)="${p}"`, 'i'))?.[1] || '');
  const title = meta('og:title') || strip(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)?.[1] || '');
  const desc = meta('og:description');
  const body = [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)].map((m) => strip(m[1])).filter((t) => t.length > 40).join(' ');
  return { title, text: `${desc} ${body}`.trim().slice(0, 1200) };
}

export async function fetchOfficialItems(state) {
  if (config.official?.enabled === false) return [];
  const cutoff = Date.now() - opt('maxAgeHours', 30) * 3600000;
  let links;
  try { links = await listLinks(); } catch (e) { console.warn('⚠️ الموقع الرسمي:', e.message); return []; }
  const seen = new Set(state.seen);
  const fresh = links.filter((u) => !seen.has(u) && (slugDate(u) ?? Date.now()) >= cutoff).slice(0, opt('maxPerRun', 5));
  const items = [];
  for (const link of fresh) {
    try {
      const a = await readArticle(link);
      if (!a.title) continue;
      items.push({ source: 'الموقع الرسمي لريال مدريد', official: true, title: a.title, link, date: Date.now(), snippet: a.text, filtered: true });
    } catch (e) { console.warn(`⚠️ تعذر قراءة ${link}: ${e.message}`); }
  }
  console.log(`🏛️ الموقع الرسمي: ${links.length} رابط، منها ${items.length} جديد`);
  return items;
}
