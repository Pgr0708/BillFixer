import pino from 'pino';
import { config } from '../config/index.js';

// Privacy rule: never log bodies, tokens, emails or anything document-derived.
export const logger = pino({
  level: config.logLevel,
  base: { svc: 'billfixer-api', pid: process.pid },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'req.headers["x-revenuecat-auth"]',
      'req.body',
      '*.password',
      '*.identityToken',
      '*.authorizationCode',
      '*.refreshToken',
      '*.accessToken',
      '*.email',
      '*.apiKey',
    ],
    censor: '[redacted]',
  },
  transport: config.isProd || config.isTest ? undefined : { target: 'pino-pretty', options: { colorize: true } },
});
