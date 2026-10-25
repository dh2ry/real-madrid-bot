import { config, env } from './config.js';

const MODEL = env.CLAUDE_MODEL || config.claudeModel || 'claude-sonnet-5-5';

// يرسل طلب لـ Claude، ومع webSearch يقدر Claude يبحث في الإنترنت بنفسه
export async function askClaude(prompt, { maxTokens = 2000, webSearch = false, maxSearches = 5 } = {}) {
  const messages = [{ role: 'user', content: prompt }];
  const body = { model: MODEL, max_tokens: maxTokens, messages };
  if (webSearch) {
    body.tools = [{ type: config.webSearchTool || 'web_search_20250305', name: 'web_search', max_uses: maxSearches }];
  }
  for (let round = 0; round < 4; round++) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`Claude API ${res.status}: ${await res.text()}`);
    const data = await res.json();
    if (data.stop_reason === 'pause_turn') { // بحث طويل: نكمل من حيث وقف
      messages.push({ role: 'assistant', content: data.content });
      continue;
    }
    return data.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  }
  throw new Error('Claude: لم يكتمل الرد');
}

// يستخرج آخر كائن JSON صالح من النص
export function parseJson(text) {
  const end = text.lastIndexOf('}');
  for (let i = text.indexOf('{'); i !== -1 && i < end; i = text.indexOf('{', i + 1)) {
    try { return JSON.parse(text.slice(i, end + 1)); } catch { /* جرّب اللي بعده */ }
  }
  throw new Error('Claude: ما رجع JSON صالح');
}

export const fitsTweet = (t) => typeof t === 'string' && t.trim() && [...t].length <= 280;
