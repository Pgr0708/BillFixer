import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { notFound } from '../lib/errors.js';
import { mapCaseSummary, mapDeadline, mapEvent, mapLetter, mapScript } from '../repositories/mappers.js';
import { requireOwnedCase, assertCanCreateCase } from '../services/caseService.js';
import * as v from '../validators/index.js';
import * as cases from '../repositories/caseRepo.js';
import * as bills from '../repositories/billRepo.js';
import * as content from '../repositories/contentRepo.js';
import { toIso } from '../lib/time.js';

export const caseRoutes = Router();

caseRoutes.get('/cases', validate({ query: v.listCasesQuery }), async (req, res) => {
  const rows = await cases.list(req.user.id, req.validQuery);
  res.json({ cases: rows.map(mapCaseSummary) });
});

caseRoutes.post('/cases', validate({ body: v.createCase }), async (req, res) => {
  await assertCanCreateCase(req);
  const caseId = await cases.create(req.user.id, req.body);
  res.status(201).json({ caseId, case: mapCaseSummary(await cases.getOwned(req.user.id, caseId)) });
});

caseRoutes.get('/cases/:caseId', validate({ params: v.caseParams }), async (req, res) => {
  const row = await requireOwnedCase(req.user.id, req.params.caseId);
  const [documents, deadlines, letters, scripts] = await Promise.all([
    cases.listDocuments(row.id), cases.listDeadlines(row.id), content.listLetters(row.id), content.listScripts(row.id),
  ]);
  res.json({
    case: { ...mapCaseSummary(row), notes: row.notes ?? null, insurerName: row.insurer_name ?? null, providerId: row.provider_id ?? null,
      finalBalance: row.final_balance ?? null },
    documents: documents.map((d) => ({ id: d.id, type: d.type, source: d.source, pageCount: d.page_count,
      ocrConfidence: d.ocr_confidence !== null ? Number(d.ocr_confidence) : null, createdAt: toIso(d.created_at) })),
    deadlines: deadlines.map(mapDeadline),
    letters: letters.map((l) => { const m = mapLetter(l); delete m.content; return m; }),
    scripts: scripts.map((s) => ({ id: s.id, callTarget: s.call_target, issueType: s.issue_type, createdAt: toIso(s.created_at) })),
  });
});

caseRoutes.patch('/cases/:caseId', validate({ params: v.caseParams, body: v.patchCase }), async (req, res) => {
  const before = await requireOwnedCase(req.user.id, req.params.caseId);
  await cases.update(req.user.id, req.params.caseId, req.body);
  if (req.body.currentBalance !== undefined && String(before.current_balance) !== req.body.currentBalance) {
    await cases.addEvent(req.params.caseId, 'balance_updated', `Balance updated to $${req.body.currentBalance}`,
      { from: before.current_balance, to: req.body.currentBalance });
  }
  res.json({ case: mapCaseSummary(await cases.getOwned(req.user.id, req.params.caseId)) });
});

caseRoutes.delete('/cases/:caseId', validate({ params: v.caseParams }), async (req, res) => {
  if (!(await cases.remove(req.user.id, req.params.caseId))) throw notFound('Case');
  res.status(204).end();
});

// ── Documents (metadata only — images never leave the phone) ──
caseRoutes.post('/cases/:caseId/documents', validate({ params: v.caseParams, body: v.createDocument }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.status(201).json({ documentId: await cases.addDocument(req.params.caseId, req.body) });
});

// ── Structured data after on-device OCR + user review ──
caseRoutes.post('/cases/:caseId/bill', validate({ params: v.caseParams, body: v.submitBill }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.status(201).json({ billId: await bills.replaceBill(req.params.caseId, req.body) });
});
caseRoutes.post('/cases/:caseId/eob', validate({ params: v.caseParams, body: v.submitEob }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.status(201).json({ eobId: await bills.replaceEob(req.params.caseId, req.body) });
});
caseRoutes.post('/cases/:caseId/gfe', validate({ params: v.caseParams, body: v.submitGfe }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.status(201).json({ gfeId: await bills.upsertGfe(req.params.caseId, req.body) });
});

// ── Deadlines ──
caseRoutes.get('/cases/:caseId/deadlines', validate({ params: v.caseParams }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.json({ deadlines: (await cases.listDeadlines(req.params.caseId)).map(mapDeadline) });
});
caseRoutes.post('/cases/:caseId/deadlines', validate({ params: v.caseParams, body: v.createDeadline }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.status(201).json({ deadlineId: await cases.addDeadline(req.params.caseId, req.body) });
});
caseRoutes.patch('/cases/:caseId/deadlines/:deadlineId', validate({ params: v.caseChildParams('deadlineId'), body: v.patchDeadline }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  if (!(await cases.updateDeadline(req.params.caseId, req.params.deadlineId, req.body))) throw notFound('Deadline');
  res.status(204).end();
});
caseRoutes.delete('/cases/:caseId/deadlines/:deadlineId', validate({ params: v.caseChildParams('deadlineId') }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  if (!(await cases.deleteDeadline(req.params.caseId, req.params.deadlineId))) throw notFound('Deadline');
  res.status(204).end();
});

// ── Timeline ──
caseRoutes.get('/cases/:caseId/events', validate({ params: v.caseParams }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.json({ events: (await cases.listEvents(req.params.caseId)).map(mapEvent) });
});
caseRoutes.post('/cases/:caseId/events', validate({ params: v.caseParams, body: v.createNote }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  await cases.addEvent(req.params.caseId, 'note_added', req.body.label, null, true);
  res.status(201).json({ ok: true });
});

// ── Outcome ──
caseRoutes.post('/cases/:caseId/resolve', validate({ params: v.caseParams, body: v.resolveCase }), async (req, res) => {
  const row = await cases.resolve(req.user.id, req.params.caseId, req.body);
  if (!row) throw notFound('Case');
  res.json({ verifiedSavings: row.verified_savings !== null ? String(row.verified_savings) : null });
});

// ── Letters & scripts (read side — generation lives in content routes) ──
caseRoutes.get('/cases/:caseId/letters/:letterId', validate({ params: v.caseChildParams('letterId') }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  const letter = await content.getLetter(req.params.caseId, req.params.letterId);
  if (!letter) throw notFound('Letter');
  res.json(mapLetter(letter));
});
caseRoutes.patch('/cases/:caseId/letters/:letterId', validate({ params: v.caseChildParams('letterId'), body: v.patchLetter }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  if (!(await content.updateLetterContent(req.params.caseId, req.params.letterId, req.body.content))) throw notFound('Letter');
  res.json(mapLetter(await content.getLetter(req.params.caseId, req.params.letterId)));
});
caseRoutes.post('/cases/:caseId/letters/:letterId/mark-sent', validate({ params: v.caseChildParams('letterId'), body: v.markSent }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  const sentAt = req.body.sentAt ? new Date(req.body.sentAt) : new Date();
  if (!(await content.markLetterSent(req.params.caseId, req.params.letterId, sentAt))) throw notFound('Letter');
  res.json({ sentAt: sentAt.toISOString() });
});
caseRoutes.get('/cases/:caseId/scripts/:scriptId', validate({ params: v.caseChildParams('scriptId') }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  const script = await content.getScript(req.params.caseId, req.params.scriptId);
  if (!script) throw notFound('Script');
  res.json(mapScript(script));
});
