#!/usr/bin/env node
/**
 * Apply db/schema.sql (and db/seed.sql with --seed). Both files are idempotent;
 * checksums are recorded in schema_migrations so you can see what ran and when.
 *   npm run migrate          → schema only
 *   npm run migrate:seed     → schema + reference seed
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import mysql from 'mysql2/promise';

const dir = path.dirname(fileURLToPath(import.meta.url));
const withSeed = process.argv.includes('--seed');

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'billfixer',
    multipleStatements: true, // migrations only — the app pool keeps this OFF
    timezone: 'Z',
    connectTimeout: 15_000,
  });
  try {
    const files = ['schema.sql', ...(withSeed ? ['seed.sql'] : [])];
    for (const file of files) {
      const sql = await readFile(path.join(dir, file), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      process.stdout.write(`→ applying ${file} … `);
      await conn.query(sql);
      await conn.query(
        `INSERT INTO schema_migrations (name, checksum) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE checksum = VALUES(checksum), applied_at = CURRENT_TIMESTAMP`,
        [file, checksum],
      );
      console.log('done');
    }
    const [[{ scheduler }]] = await conn.query("SELECT @@event_scheduler AS scheduler");
    if (String(scheduler).toUpperCase() !== 'ON') {
      console.warn('⚠ event_scheduler is OFF — housekeeping events will not run. See deploy/setup-server.sh.');
    }
    console.log('✓ migrations complete');
  } finally {
    await conn.end();
  }
}

main().catch((err) => {
  console.error('✗ migration failed:', err.message);
  process.exit(1);
});
