import mysql from 'mysql2/promise';
import { config } from '../config/index.js';
import { logger } from './logger.js';

const baseOptions = {
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  waitForConnections: true,
  connectionLimit: config.db.poolSize,
  maxIdle: config.db.poolSize,
  idleTimeout: 60_000,
  queueLimit: 1000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 10_000,
  connectTimeout: 10_000,
  timezone: 'Z',
  charset: 'utf8mb4',
  decimalNumbers: false, // DECIMAL stays a string → exact cents parsing
  dateStrings: ['DATE'], // DATE → 'YYYY-MM-DD'; DATETIME → JS Date (UTC)
  supportBigNumbers: true,
  multipleStatements: false,
};

// Session settings per connection, so BillFixer never needs to change server-wide MySQL config
// (important when the database server is shared with other sites).
const SESSION_SQL = "SET time_zone = '+00:00', sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'";
function withSession(pool) {
  pool.pool.on('connection', (conn) => conn.query(SESSION_SQL, (err) => { if (err) logger.error({ err }, 'session setup failed'); }));
  return pool;
}

const primary = withSession(mysql.createPool({ ...baseOptions, host: config.db.host }));
const replica = config.db.readHost ? withSession(mysql.createPool({ ...baseOptions, host: config.db.readHost })) : primary;

const TRANSIENT = new Set([
  'ER_LOCK_DEADLOCK',
  'ER_LOCK_WAIT_TIMEOUT',
  'PROTOCOL_CONNECTION_LOST',
  'ECONNRESET',
  'ETIMEDOUT',
  'EPIPE',
  'ER_CON_COUNT_ERROR',
]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function withRetry(fn, attempts = 3) {
  let lastError;
  for (let i = 0; i < attempts; i += 1) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (!TRANSIENT.has(err.code) || i === attempts - 1) throw err;
      const wait = 80 * 2 ** i + Math.floor(Math.random() * 60);
      logger.warn({ code: err.code, attempt: i + 1 }, 'db transient error, retrying');
      await sleep(wait);
    }
  }
  throw lastError;
}

/** Run a parameterised query. SELECTs may be routed to the read replica with { read: true }. */
export async function query(sql, params = [], { read = false } = {}) {
  const pool = read ? replica : primary;
  const [rows] = await withRetry(() => pool.execute(sql, params));
  return rows;
}

/** `query` variant that uses the text protocol (needed for IN (?) array expansion). */
export async function queryText(sql, params = [], { read = false } = {}) {
  const pool = read ? replica : primary;
  const [rows] = await withRetry(() => pool.query(sql, params));
  return rows;
}

export async function one(sql, params = [], opts) {
  const rows = await query(sql, params, opts);
  return rows[0] ?? null;
}

/**
 * Run `fn(conn)` inside a transaction. Retries the whole transaction on deadlock.
 * `conn.q(sql, params)` returns rows.
 */
export async function transaction(fn) {
  return withRetry(async () => {
    const conn = await primary.getConnection();
    const q = async (sql, params = []) => (await conn.execute(sql, params))[0];
    const qt = async (sql, params = []) => (await conn.query(sql, params))[0];
    try {
      await conn.beginTransaction();
      const result = await fn({ q, qt, conn });
      await conn.commit();
      return result;
    } catch (err) {
      try {
        await conn.rollback();
      } catch (rollbackErr) {
        logger.error({ err: rollbackErr }, 'rollback failed');
      }
      throw err;
    } finally {
      conn.release();
    }
  });
}

export async function ping() {
  const started = Date.now();
  await primary.query('SELECT 1');
  return Date.now() - started;
}

export async function closeDb() {
  await primary.end().catch(() => {});
  if (replica !== primary) await replica.end().catch(() => {});
}
