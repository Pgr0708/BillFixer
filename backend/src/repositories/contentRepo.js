import { query, one } from '../lib/db.js';
import { uuid } from '../lib/ids.js';
import { addEvent } from './caseRepo.js';

// ── Letters ──
export async function insertLetter(caseId, l) {
  const id = uuid();
  await query(
    `INSERT INTO letters (id, case_id, finding_id, type, recipient_name, recipient_type, subject, content, is_fallback)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, caseId, l.findingId ?? null, l.type, l.recipientName ?? null, l.recipientType ?? 'provider', l.subject ?? null, l.content, l.isFallback ? 1 : 0],
  );
  await addEvent(caseId, 'letter_generated', `Letter drafted: ${l.subject ?? l.type.replace(/_/g, ' ')}`, { letterId: id });
  return id;
}
export const listLetters = (caseId) =>
  query('SELECT * FROM letters WHERE case_id = ? ORDER BY created_at DESC', [caseId], { read: true });
export const getLetter = (caseId, letterId) => one('SELECT * FROM letters WHERE id = ? AND case_id = ?', [letterId, caseId]);
export const updateLetterContent = async (caseId, letterId, content) =>
  (await query('UPDATE letters SET content = ?, version = version + 1 WHERE id = ? AND case_id = ?', [content, letterId, caseId])).affectedRows;
export async function markLetterSent(caseId, letterId, sentAt) {
  const res = await query('UPDATE letters SET sent_at = ? WHERE id = ? AND case_id = ?', [sentAt, letterId, caseId]);
  if (res.affectedRows) {
    await addEvent(caseId, 'letter_sent', 'Letter sent', { letterId });
    await query("UPDATE cases SET status = 'awaiting_response' WHERE id = ? AND status IN ('draft','active')", [caseId]);
  }
  return res.affectedRows;
}

// ── Phone scripts ──
export async function insertScript(caseId, s) {
  const id = uuid();
  await query(
    'INSERT INTO phone_scripts (id, case_id, finding_id, call_target, issue_type, content, is_fallback) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, caseId, s.findingId ?? null, s.callTarget, s.issueType, JSON.stringify(s.content), s.isFallback ? 1 : 0],
  );
  await addEvent(caseId, 'script_generated', 'Phone script prepared', { scriptId: id });
  return id;
}
export const getScript = (caseId, scriptId) => one('SELECT * FROM phone_scripts WHERE id = ? AND case_id = ?', [scriptId, caseId]);
export const listScripts = (caseId) =>
  query('SELECT * FROM phone_scripts WHERE case_id = ? ORDER BY created_at DESC', [caseId], { read: true });
