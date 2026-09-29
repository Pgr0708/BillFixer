import { config } from '../config/index.js';
import { logger } from '../lib/logger.js';
import { CircuitBreaker } from '../lib/circuitBreaker.js';
import { redactDeep } from '../lib/redact.js';
import { PROHIBITED_PATTERNS } from '../lib/contentGuard.js';

/**
 * The LLM is a writer, never an analyzer (ADR-001/003). It only ever sees a redacted,
 * structured evidence bundle, must answer in JSON, and every answer is validated by the
 * caller. Any failure → `null`, and the caller uses its deterministic template.
 */
const breaker = new CircuitBreaker('openai', { windowMs: 5 * 60_000, failureRatio: 0.2, minSamples: 8, openMs: 60_000 });
const isReasoningModel = (m) => /^o\d/.test(m);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export const llmStatus = () => (config.llm.enabled ? breaker.status() : 'disabled');

class LlmHttpError extends Error {
  constructor(status, retryAfterMs) {
    super(`LLM HTTP ${status}`);
    this.status = status;
    this.retryAfterMs = retryAfterMs;
  }
}

async function callOpenAI(messages, maxTokens) {
  const model = config.llm.model;
  const body = {
    model,
    messages,
    response_format: { type: 'json_object' },
    // Reasoning models spend completion tokens on hidden reasoning; give them headroom.
    max_completion_tokens: isReasoningModel(model) ? maxTokens * 4 : maxTokens,
    ...(isReasoningModel(model) ? {} : { temperature: 0.3 }),
  };
  const res = await fetch(`${config.llm.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.llm.apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(config.llm.timeoutMs),
  });
  if (!res.ok) {
    const retryAfter = Number(res.headers.get('retry-after'));
    throw new LlmHttpError(res.status, Number.isFinite(retryAfter) ? retryAfter * 1000 : null);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content.trim()) throw new Error('LLM returned empty content');
  return content;
}

/**
 * @param {object} o
 * @param {string} o.task      label for logs
 * @param {string} o.system    system prompt
 * @param {object} o.input     structured evidence (redacted again here)
 * @param {(obj:object)=>{ok:boolean,value?:any,reason?:string}} o.validate
 * @param {number} [o.maxTokens]
 * @returns {Promise<any|null>}
 */
export async function generateJson({ task, system, input, validate, maxTokens = 1200 }) {
  if (!config.llm.enabled) return null;
  if (!breaker.canRequest()) {
    logger.warn({ task }, 'llm circuit open — using fallback');
    return null;
  }
  const messages = [
    { role: 'system', content: system },
    { role: 'user', content: JSON.stringify(redactDeep(input)) },
  ];

  for (let attempt = 0; attempt < 3; attempt += 1) {
    let raw;
    try {
      raw = await callOpenAI(messages, maxTokens);
      breaker.record(true);
    } catch (err) {
      breaker.record(false);
      const status = err.status;
      logger.warn({ task, attempt, status, err: err.message }, 'llm call failed');
      if (status && status >= 400 && status < 500 && status !== 429 && status !== 408) return null; // not retryable
      if (!breaker.canRequest()) return null;
      await sleep(err.retryAfterMs ?? 500 * 2 ** attempt + Math.random() * 250);
      continue;
    }

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = null;
    }
    const result = parsed ? validate(parsed) : { ok: false, reason: 'invalid_json' };
    if (result.ok) return result.value;

    logger.info({ task, attempt, reason: result.reason }, 'llm output rejected, requesting correction');
    messages.push(
      { role: 'assistant', content: raw.slice(0, 8000) },
      {
        role: 'user',
        content: `Your response was rejected (${result.reason}). Return only corrected JSON in the same schema. `
          + 'Use only dollar amounts that appear in the input. Never use words matching: '
          + PROHIBITED_PATTERNS.map((p) => p.source.replace(/\\b|\(|\)|\?|\\/g, '')).join(', ') + '.',
      },
    );
  }
  return null;
}

export const SYSTEM_BASE = [
  'You are a medical billing analyst assistant helping a patient understand a bill and take action.',
  'You do NOT provide legal advice. You do NOT guarantee outcomes. You do NOT claim errors are fraud or illegal.',
  'Every statement must be grounded in the evidence provided. Only use dollar amounts that appear in the input, formatted like $1,234.56.',
  'Tone: calm, respectful, factual, plain English at an 8th-grade reading level.',
  'Respond with a single JSON object only.',
].join(' ');
