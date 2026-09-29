import { transaction, query, one } from '../lib/db.js';
import { uuid } from '../lib/ids.js';
import { addEvent } from './caseRepo.js';

/**
 * Replace the case's bill (1:1). The old bill's line items cascade away with it.
 * Also syncs the case header (provider, balances) so list screens stay correct.
 */
export async function replaceBill(caseId, b) {
  return transaction(async (conn) => {
    await conn.q('DELETE FROM bills WHERE case_id = ?', [caseId]);
    const billId = uuid();
    await conn.q(
      `INSERT INTO bills (id, case_id, document_id, provider_name, provider_npi, account_number, bill_date, service_date_start,
         service_date_end, insurer_name, member_id_redacted, total_charges, insurance_payment, adjustments, previous_payments,
         patient_responsibility, current_balance, is_itemized, raw_ocr_confidence)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [billId, caseId, b.documentId ?? null, b.providerName, b.providerNpi ?? null, b.accountNumber ?? null, b.billDate ?? null,
        b.serviceDateStart ?? null, b.serviceDateEnd ?? null, b.insurerName ?? null, b.memberIdLast4 ?? null,
        b.totalCharges ?? null, b.insurancePayment ?? null, b.adjustments ?? null, b.previousPayments ?? null,
        b.patientResponsibility ?? null, b.currentBalance ?? null, b.isItemized ? 1 : 0, b.ocrConfidence ?? null],
    );
    if (b.lineItems.length) {
      // Bulk insert (text protocol expands the nested array).
      const rows = b.lineItems.map((li, i) => [uuid(), billId, li.lineNumber ?? i + 1, li.code ?? null, li.description,
        li.dateOfService ?? null, li.quantity ?? '1', li.unitPrice ?? null, li.totalAmount, li.adjustment ?? null,
        li.isUserEdited ? 1 : 0, li.ocrConfidence ?? null]);
      await conn.qt(`INSERT INTO bill_line_items (id, bill_id, line_number, code, description, date_of_service, quantity,
        unit_price, total_amount, adjustment, is_user_edited, ocr_confidence) VALUES ?`, [rows]);
    }
    const balance = b.currentBalance ?? b.patientResponsibility ?? null;
    await conn.q(
      `UPDATE cases SET provider_name = ?, insurer_name = COALESCE(?, insurer_name), bill_date = COALESCE(?, bill_date),
         initial_bill_date = COALESCE(initial_bill_date, ?), original_balance = COALESCE(original_balance, ?),
         current_balance = ?, provider_id = COALESCE(?, provider_id), status = IF(status = 'draft', 'active', status)
       WHERE id = ?`,
      [b.providerName, b.insurerName ?? null, b.billDate ?? null, b.billDate ?? null, balance, balance, b.providerId ?? null, caseId],
    );
    await addEvent(caseId, 'document_added', `Bill details confirmed · ${b.lineItems.length} line items`, null, false, conn);
    return billId;
  });
}

export async function replaceEob(caseId, e) {
  return transaction(async (conn) => {
    await conn.q('DELETE FROM eobs WHERE case_id = ?', [caseId]);
    const eobId = uuid();
    await conn.q(
      `INSERT INTO eobs (id, case_id, document_id, claim_number, eob_date, insurer_name, member_id_redacted, service_date_start,
         service_date_end, provider_name, network_status, billed_amount, allowed_amount, insurer_payment, deductible_applied,
         copay, coinsurance, patient_responsibility)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [eobId, caseId, e.documentId ?? null, e.claimNumber ?? null, e.eobDate ?? null, e.insurerName ?? null, e.memberIdLast4 ?? null,
        e.serviceDateStart ?? null, e.serviceDateEnd ?? null, e.providerName ?? null, e.networkStatus ?? 'unknown',
        e.billedAmount ?? null, e.allowedAmount ?? null, e.insurerPayment ?? null, e.deductibleApplied ?? null, e.copay ?? null,
        e.coinsurance ?? null, e.patientResponsibility ?? null],
    );
    if (e.lineItems?.length) {
      const rows = e.lineItems.map((li, i) => [uuid(), eobId, li.lineNumber ?? i + 1, li.code ?? null, li.description ?? null,
        li.dateOfService ?? null, li.billedAmount ?? null, li.allowedAmount ?? null, li.insurerPaid ?? null,
        li.patientResponsibility ?? null, li.networkStatus ?? 'unknown']);
      await conn.qt(`INSERT INTO eob_line_items (id, eob_id, line_number, code, description, date_of_service, billed_amount,
        allowed_amount, insurer_paid, patient_responsibility, network_status) VALUES ?`, [rows]);
    }
    if (e.insurerName) await conn.q('UPDATE cases SET insurer_name = ? WHERE id = ?', [e.insurerName, caseId]);
    await addEvent(caseId, 'document_added', `EOB details confirmed${e.claimNumber ? ` · claim ${e.claimNumber}` : ''}`, null, false, conn);
    return eobId;
  });
}

export async function upsertGfe(caseId, g) {
  const id = uuid();
  await query(
    `INSERT INTO good_faith_estimates (id, case_id, provider_name, estimate_date, total_estimate) VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE provider_name = VALUES(provider_name), estimate_date = VALUES(estimate_date), total_estimate = VALUES(total_estimate)`,
    [id, caseId, g.providerName ?? null, g.estimateDate ?? null, g.totalEstimate],
  );
  await addEvent(caseId, 'document_added', 'Good Faith Estimate added');
  return (await one('SELECT id FROM good_faith_estimates WHERE case_id = ?', [caseId])).id;
}

/** Everything the engine needs, in one round-trip per table. */
export async function loadForAnalysis(caseId) {
  const [bill, eob, gfe, caseRow] = await Promise.all([
    one('SELECT * FROM bills WHERE case_id = ?', [caseId]),
    one('SELECT * FROM eobs WHERE case_id = ?', [caseId]),
    one('SELECT * FROM good_faith_estimates WHERE case_id = ?', [caseId]),
    one('SELECT id, provider_id, initial_bill_date, bill_date FROM cases WHERE id = ?', [caseId]),
  ]);
  const [lines, eobLines] = await Promise.all([
    bill ? query('SELECT * FROM bill_line_items WHERE bill_id = ? ORDER BY line_number', [bill.id]) : [],
    eob ? query('SELECT * FROM eob_line_items WHERE eob_id = ? ORDER BY line_number', [eob.id]) : [],
  ]);
  return { caseRow, bill, lines, eob, eobLines, gfe };
}
