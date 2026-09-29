import { query, one, transaction } from '../lib/db.js';
import { uuid } from '../lib/ids.js';

const SUMMARY_COLS = `c.*,
  (SELECT COUNT(*) FROM findings f WHERE f.case_id = c.id AND f.status = 'open' AND f.severity <> 'informational') AS finding_count,
  (SELECT JSON_OBJECT('label', d.label, 'dueDate', DATE_FORMAT(d.due_date, '%Y-%m-%d'), 'type', d.type)
     FROM deadlines d WHERE d.case_id = c.id AND d.is_completed = 0 ORDER BY d.due_date LIMIT 1) AS next_deadline`;

export function list(userId, { status, q, limit = 50, offset = 0 }) {
  const where = ['c.user_id = ?'];
  const params = [userId];
  if (status) { where.push('c.status = ?'); params.push(status); }
  if (q) { where.push('(c.title LIKE ? OR c.provider_name LIKE ?)'); params.push(`%${q}%`, `%${q}%`); }
  // LIMIT/OFFSET are validated integers, inlined to avoid mysql2 prepared-statement type issues.
  return query(`SELECT ${SUMMARY_COLS} FROM cases c WHERE ${where.join(' AND ')}
                ORDER BY c.updated_at DESC LIMIT ${Number(limit)} OFFSET ${Number(offset)}`, params, { read: true });
}

export const getOwned = (userId, caseId) =>
  one(`SELECT ${SUMMARY_COLS} FROM cases c WHERE c.id = ? AND c.user_id = ?`, [caseId, userId]);

export const countActive = async (userId) =>
  Number((await one("SELECT COUNT(*) AS n FROM cases WHERE user_id = ? AND status IN ('draft','active','awaiting_response')", [userId]))?.n ?? 0);

export async function create(userId, { title, billDate, serviceType }) {
  const id = uuid();
  await transaction(async ({ q }) => {
    await q('INSERT INTO cases (id, user_id, title, bill_date, initial_bill_date, service_type) VALUES (?, ?, ?, ?, ?, ?)',
      [id, userId, title, billDate ?? null, billDate ?? null, serviceType ?? null]);
    await q("INSERT INTO case_events (id, case_id, type, label) VALUES (?, ?, 'case_created', 'Case created')", [uuid(), id]);
  });
  return id;
}

const PATCHABLE = { title: 'title', status: 'status', currentBalance: 'current_balance', notes: 'notes', providerId: 'provider_id' };

export async function update(userId, caseId, patch) {
  const sets = [];
  const params = [];
  for (const [key, col] of Object.entries(PATCHABLE)) {
    if (patch[key] !== undefined) { sets.push(`${col} = ?`); params.push(patch[key]); }
  }
  if (!sets.length) return 0;
  const res = await query(`UPDATE cases SET ${sets.join(', ')} WHERE id = ? AND user_id = ?`, [...params, caseId, userId]);
  return res.affectedRows;
}

/** Hard delete. FKs cascade to documents, bill, EOB, GFE, findings, evidence, letters, scripts, deadlines, events, outcome, jobs. */
export async function remove(userId, caseId) {
  const res = await query('DELETE FROM cases WHERE id = ? AND user_id = ?', [caseId, userId]);
  return res.affectedRows;
}

export async function addEvent(caseId, type, label, metadata = null, isUserLog = false, conn) {
  const sql = 'INSERT INTO case_events (id, case_id, type, label, metadata, is_user_log) VALUES (?, ?, ?, ?, ?, ?)';
  const params = [uuid(), caseId, type, label.slice(0, 500), metadata ? JSON.stringify(metadata) : null, isUserLog ? 1 : 0];
  return conn ? conn.q(sql, params) : query(sql, params);
}

export const listEvents = (caseId) =>
  query('SELECT * FROM case_events WHERE case_id = ? ORDER BY occurred_at DESC, id LIMIT 200', [caseId], { read: true });

export const listDocuments = (caseId) =>
  query('SELECT id, type, source, page_count, ocr_confidence, created_at FROM documents WHERE case_id = ? ORDER BY created_at', [caseId], { read: true });

export async function addDocument(caseId, { type, source, pageCount, ocrConfidence, sha256 }) {
  const id = uuid();
  await query('INSERT INTO documents (id, case_id, type, source, page_count, ocr_confidence, sha256) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, caseId, type, source, pageCount, ocrConfidence ?? null, sha256 ?? null]);
  await addEvent(caseId, 'document_added', `${type === 'eob' ? 'EOB' : type === 'gfe' ? 'Good Faith Estimate' : 'Bill'} added · ${pageCount} page${pageCount === 1 ? '' : 's'}`);
  return id;
}

// ── Deadlines ──
export const listDeadlines = (caseId) =>
  query('SELECT * FROM deadlines WHERE case_id = ? ORDER BY is_completed, due_date', [caseId], { read: true });

export async function addDeadline(caseId, { type, label, dueDate, notifyDays }) {
  const id = uuid();
  await query('INSERT INTO deadlines (id, case_id, type, label, due_date, notify_days) VALUES (?, ?, ?, ?, ?, ?)',
    [id, caseId, type, label, dueDate, JSON.stringify(notifyDays ?? [14, 7, 1])]);
  await addEvent(caseId, 'deadline_set', `Deadline set: ${label} (${dueDate})`);
  return id;
}

export async function updateDeadline(caseId, deadlineId, { label, dueDate, isCompleted }) {
  const sets = [];
  const params = [];
  if (label !== undefined) { sets.push('label = ?'); params.push(label); }
  if (dueDate !== undefined) { sets.push('due_date = ?'); params.push(dueDate); }
  if (isCompleted !== undefined) {
    sets.push('is_completed = ?', 'completed_at = IF(? = 1, UTC_TIMESTAMP(), NULL)');
    params.push(isCompleted ? 1 : 0, isCompleted ? 1 : 0);
  }
  if (!sets.length) return 0;
  return (await query(`UPDATE deadlines SET ${sets.join(', ')} WHERE id = ? AND case_id = ?`, [...params, deadlineId, caseId])).affectedRows;
}

export const deleteDeadline = async (caseId, deadlineId) =>
  (await query('DELETE FROM deadlines WHERE id = ? AND case_id = ?', [deadlineId, caseId])).affectedRows;

// ── Outcome ──
export async function resolve(userId, caseId, { resolution, finalBalance, notes }) {
  return transaction(async (conn) => {
    const [c] = await conn.q('SELECT original_balance FROM cases WHERE id = ? AND user_id = ? FOR UPDATE', [caseId, userId]);
    if (!c) return null;
    await conn.q(
      `INSERT INTO outcomes (id, case_id, resolution, original_balance, final_balance, notes) VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE resolution = VALUES(resolution), final_balance = VALUES(final_balance), notes = VALUES(notes), resolved_at = UTC_TIMESTAMP()`,
      [uuid(), caseId, resolution, c.original_balance, finalBalance, notes ?? null],
    );
    await conn.q(
      `UPDATE cases SET status = 'resolved', final_balance = ?, current_balance = ?,
         verified_savings = GREATEST(IFNULL(original_balance, 0) - ?, 0) WHERE id = ?`,
      [finalBalance, finalBalance, finalBalance, caseId],
    );
    await addEvent(caseId, 'case_resolved', 'Case resolved', { resolution, finalBalance }, false, conn);
    const [row] = await conn.q('SELECT verified_savings FROM cases WHERE id = ?', [caseId]);
    return row;
  });
}
