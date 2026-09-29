import { transaction, query, queryText } from '../lib/db.js';
import { uuid } from '../lib/ids.js';
import { fromCents } from '../lib/money.js';
import { addEvent } from './caseRepo.js';

/** Replace a case's findings with a fresh analysis result (evidence cascades). */
export async function replaceFindings(caseId, findings, { potentialSavingsCents }) {
  return transaction(async (conn) => {
    await conn.q('DELETE FROM findings WHERE case_id = ?', [caseId]);
    const findingRows = [];
    const evidenceRows = [];
    findings.forEach((f, i) => {
      const id = uuid();
      findingRows.push([id, caseId, f.type, f.severity, f.confidence, f.title.slice(0, 500), f.explanation,
        f.whatYouCanDo?.slice(0, 600) ?? null, f.counterCase?.slice(0, 600) ?? null,
        fromCents(f.amountFlagged), fromCents(f.amountReference), fromCents(f.amountDifference),
        f.recommendedAction ?? null, f.deadlineDate ?? null, i, f.llmExplained ? 1 : 0]);
      f.evidence.forEach((e, j) => evidenceRows.push([uuid(), id, e.sourceType, e.sourceRef ?? null,
        String(e.label).slice(0, 500), e.value === null || e.value === undefined ? null : String(e.value).slice(0, 500), e.url ?? null, j]));
    });
    if (findingRows.length) {
      await conn.qt(`INSERT INTO findings (id, case_id, type, severity, confidence, title, explanation, what_you_can_do,
        counter_case, amount_flagged, amount_reference, amount_difference, recommended_action, deadline_date, sort_order,
        llm_explained) VALUES ?`, [findingRows]);
    }
    if (evidenceRows.length) {
      await conn.qt('INSERT INTO finding_evidence (id, finding_id, source_type, source_ref, label, value, url, sort_order) VALUES ?', [evidenceRows]);
    }
    await conn.q('UPDATE cases SET potential_savings = ?, last_analyzed_at = UTC_TIMESTAMP() WHERE id = ?',
      [fromCents(potentialSavingsCents), caseId]);
    const countable = findings.filter((f) => f.severity !== 'informational').length;
    await addEvent(caseId, 'analysis_run', `Analysis complete · ${countable} finding${countable === 1 ? '' : 's'}`,
      { findings: countable }, false, conn);
    // Deadline-bearing findings (e.g. 120-day GFE window) become case deadlines.
    for (const f of findings.filter((x) => x.deadlineDate && x.type === 'gfe_dispute_eligible')) {
      await conn.q(`INSERT INTO deadlines (id, case_id, type, label, due_date, notify_days)
                    SELECT ?, ?, 'ppdr_120day', 'Good Faith Estimate dispute window closes', ?, ?
                    WHERE NOT EXISTS (SELECT 1 FROM deadlines WHERE case_id = ? AND type = 'ppdr_120day')`,
      [uuid(), caseId, f.deadlineDate, JSON.stringify([14, 7, 1]), caseId]);
    }
    return findingRows.map((r) => r[0]);
  });
}

export async function listWithEvidence(caseId) {
  const findings = await query('SELECT * FROM findings WHERE case_id = ? ORDER BY sort_order', [caseId], { read: true });
  if (!findings.length) return [];
  const evidence = await queryText('SELECT * FROM finding_evidence WHERE finding_id IN (?) ORDER BY sort_order', [findings.map((f) => f.id)], { read: true });
  const byFinding = new Map();
  for (const e of evidence) {
    if (!byFinding.has(e.finding_id)) byFinding.set(e.finding_id, []);
    byFinding.get(e.finding_id).push(e);
  }
  return findings.map((f) => ({ row: f, evidence: byFinding.get(f.id) ?? [] }));
}

export async function getOne(caseId, findingId) {
  const [row] = await query('SELECT * FROM findings WHERE id = ? AND case_id = ?', [findingId, caseId]);
  if (!row) return null;
  const evidence = await query('SELECT * FROM finding_evidence WHERE finding_id = ? ORDER BY sort_order', [findingId]);
  return { row, evidence };
}

export async function updateStatus(caseId, findingId, status) {
  const res = await query(
    "UPDATE findings SET status = ?, dismissed_at = IF(? = 'dismissed', UTC_TIMESTAMP(), NULL) WHERE id = ? AND case_id = ?",
    [status, status, findingId, caseId],
  );
  return res.affectedRows;
}
