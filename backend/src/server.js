import http from 'node:http';
import { config } from './config/index.js';
import { logger } from './lib/logger.js';
import { closeDb } from './lib/db.js';
import { initRedis, closeRedis } from './lib/redis.js';
import { startSweeper, drain } from './services/jobRunner.js';
import { createApp } from './app.js';

initRedis();
startSweeper();

const server = http.createServer(createApp());
// Keep-alive must outlive nginx's upstream keepalive so nginx never reuses a closed socket.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;
server.requestTimeout = 60_000;

server.listen(config.port, config.host, () => {
  logger.info({ host: config.host, port: config.port, env: config.env, llm: config.llm.enabled ? config.llm.model : 'disabled' }, 'billfixer api listening');
  if (process.send) process.send('ready'); // PM2 wait_ready → zero-downtime reloads
});

let shuttingDown = false;
async function shutdown(signal, code = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down gracefully');
  const force = setTimeout(() => {
    logger.error('forced exit after shutdown timeout');
    process.exit(1);
  }, 25_000);
  force.unref();
  server.close();
  server.closeIdleConnections?.();
  await drain(15_000);
  await Promise.allSettled([closeDb(), closeRedis()]);
  logger.info('shutdown complete');
  process.exit(code);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  // Log and keep serving — one bad promise must not take the API down.
  logger.error({ err: reason instanceof Error ? { message: reason.message, stack: reason.stack } : reason }, 'unhandled rejection');
});
process.on('uncaughtException', (err) => {
  // State may be corrupt: stop cleanly and let PM2 start a fresh process.
  logger.fatal({ err: { message: err.message, stack: err.stack } }, 'uncaught exception');
  shutdown('uncaughtException', 1);
});
