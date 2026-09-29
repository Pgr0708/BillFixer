import 'dotenv/config';
import { z } from 'zod';

const bool = (def) =>
  z.preprocess((v) => (v === undefined || v === '' ? def : String(v).toLowerCase() === 'true'), z.boolean());
const int = (def) => z.coerce.number().int().default(def);
const optionalString = z.preprocess((v) => (v === '' ? undefined : v), z.string().optional());

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().default('127.0.0.1'),
  PORT: int(3000),
  TRUST_PROXY: int(1),
  PUBLIC_BASE_URL: z.string().url().default('https://billfixer.dakshyaminfotech.store'),
  CORS_ORIGINS: z.string().default('https://billfixer.dakshyaminfotech.store'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: int(3306),
  DB_USER: z.string().default('billfixer'),
  DB_PASSWORD: z.string().default(''),
  DB_NAME: z.string().default('billfixer'),
  DB_POOL_SIZE: int(10),
  DB_READ_HOST: optionalString,

  REDIS_ENABLED: bool(true),
  REDIS_URL: z.string().default('redis://127.0.0.1:6379'),
  REDIS_KEY_PREFIX: z.string().default('bf:'),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
  JWT_ACCESS_TTL_SECONDS: int(900),
  REFRESH_TTL_DAYS: int(60),
  JWT_ISSUER: z.string().default('billfixer-api'),
  JWT_AUDIENCE: z.string().default('billfixer-ios'),
  APPLE_BUNDLE_IDS: z.string().default('com.bhavik.BillFixer'),

  LLM_ENABLED: bool(true),
  OPENAI_API_KEY: optionalString,
  OPENAI_MODEL: z.string().default('gpt-4o-mini'),
  OPENAI_BASE_URL: z.string().url().default('https://api.openai.com/v1'),
  LLM_TIMEOUT_MS: int(30000),

  REVENUECAT_SECRET_KEY: optionalString,
  REVENUECAT_WEBHOOK_AUTH: optionalString,
  REVENUECAT_ENTITLEMENT: z.string().default('pro'),

  SMTP_HOST: optionalString,
  SMTP_PORT: int(465),
  SMTP_USER: optionalString,
  SMTP_PASSWORD: optionalString,
  SMTP_FROM: optionalString,

  FREE_ACTIVE_CASE_LIMIT: int(1),
  RATE_LIMIT_GLOBAL_PER_MIN: int(120),
  RATE_LIMIT_AUTH_PER_15MIN: int(10),
  RATE_LIMIT_LLM_PER_HOUR: int(30),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  // Fail fast at boot with a readable message — a misconfigured server must not start half-working.
  const issues = parsed.error.issues.map((i) => `  • ${i.path.join('.')}: ${i.message}`).join('\n');
  console.error(`\n[config] Invalid environment configuration:\n${issues}\n`);
  process.exit(1);
}

const env = parsed.data;

export const config = Object.freeze({
  env: env.NODE_ENV,
  isProd: env.NODE_ENV === 'production',
  isTest: env.NODE_ENV === 'test',
  host: env.HOST,
  port: env.PORT,
  trustProxy: env.TRUST_PROXY,
  publicBaseUrl: env.PUBLIC_BASE_URL,
  corsOrigins: env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean),
  logLevel: env.LOG_LEVEL,
  db: {
    host: env.DB_HOST,
    readHost: env.DB_READ_HOST,
    port: env.DB_PORT,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    poolSize: env.DB_POOL_SIZE,
  },
  redis: { enabled: env.REDIS_ENABLED, url: env.REDIS_URL, keyPrefix: env.REDIS_KEY_PREFIX },
  auth: {
    accessSecret: env.JWT_ACCESS_SECRET,
    accessTtlSeconds: env.JWT_ACCESS_TTL_SECONDS,
    refreshTtlDays: env.REFRESH_TTL_DAYS,
    issuer: env.JWT_ISSUER,
    audience: env.JWT_AUDIENCE,
    appleBundleIds: env.APPLE_BUNDLE_IDS.split(',').map((s) => s.trim()).filter(Boolean),
  },
  llm: {
    enabled: env.LLM_ENABLED && Boolean(env.OPENAI_API_KEY),
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_MODEL,
    baseUrl: env.OPENAI_BASE_URL.replace(/\/+$/, ''),
    timeoutMs: env.LLM_TIMEOUT_MS,
  },
  revenueCat: {
    secretKey: env.REVENUECAT_SECRET_KEY,
    webhookAuth: env.REVENUECAT_WEBHOOK_AUTH,
    entitlement: env.REVENUECAT_ENTITLEMENT,
  },
  smtp: {
    enabled: Boolean(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASSWORD),
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    user: env.SMTP_USER,
    password: env.SMTP_PASSWORD,
    from: env.SMTP_FROM || env.SMTP_USER,
  },
  limits: {
    freeActiveCases: env.FREE_ACTIVE_CASE_LIMIT,
    globalPerMin: env.RATE_LIMIT_GLOBAL_PER_MIN,
    authPer15Min: env.RATE_LIMIT_AUTH_PER_15MIN,
    llmPerHour: env.RATE_LIMIT_LLM_PER_HOUR,
  },
});
