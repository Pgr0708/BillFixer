import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import hpp from 'hpp';
import { pinoHttp } from 'pino-http';
import { config } from './config/index.js';
import { logger } from './lib/logger.js';
import { requestId } from './middleware/requestId.js';
import { rateLimit } from './middleware/rateLimit.js';
import { timeout } from './middleware/timeout.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { health } from './routes/health.js';
import { v1 } from './routes/index.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy); // real client IP from nginx for rate limiting
  app.set('json spaces', 0);

  app.use(requestId);
  app.use(pinoHttp({
    logger,
    genReqId: (req) => req.id,
    autoLogging: { ignore: (req) => req.url.startsWith('/health') },
    customLogLevel: (_req, res, err) => (err || res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info'),
    serializers: {
      // Path only — never query strings, bodies or headers.
      req: (req) => ({ id: req.id, method: req.method, path: req.url.split('?')[0] }),
      res: (res) => ({ status: res.statusCode }),
    },
  }));
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'same-site' } }));
  app.use(cors({ origin: config.corsOrigins, methods: ['GET', 'POST', 'PATCH', 'DELETE'], maxAge: 600 }));
  app.use(compression({ threshold: 1024 }));
  app.use(express.json({ limit: '512kb', strict: true }));
  app.use(hpp());

  app.use(health);
  app.use('/v1', rateLimit({ name: 'global', windowSec: 60, max: config.limits.globalPerMin }), timeout(30_000), v1);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
