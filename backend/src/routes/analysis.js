import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { rateLimit, byUserOrIp } from '../middleware/rateLimit.js';
import { idempotency } from '../middleware/idempotency.js';
import { notFound } from '../lib/errors.js';
import { config } from '../config/index.js';
import { requireOwnedCase } from '../services/caseService.js';
import * as analysis from '../services/analysisService.js';
import * as findingRepo from '../repositories/findingRepo.js';
import * as cases from '../repositories/caseRepo.js';
import * as v from '../validators/index.js';

export const analysisRoutes = Router();
const llmLimit = rateLimit({ name: 'llm', windowSec: 3600, max: config.limits.llmPerHour, key: byUserOrIp });

analysisRoutes.post('/cases/:caseId/analyze', llmLimit, validate({ params: v.caseParams, body: v.analyzeBody }), idempotency, async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  const { jobId, estimatedSeconds } = await analysis.startAnalysis(req.user.id, req.params.caseId, req.body.context);
  res.status(202).json({ jobId, estimatedSeconds });
});

analysisRoutes.get('/cases/:caseId/analysis/status', validate({ params: v.caseParams }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  res.set('Cache-Control', 'no-store');
  res.json(await analysis.status(req.params.caseId));
});

analysisRoutes.get('/cases/:caseId/findings', validate({ params: v.caseParams }), async (req, res) => {
  const row = await requireOwnedCase(req.user.id, req.params.caseId);
  res.json(await analysis.findingsFor(row, await req.tier()));
});

analysisRoutes.patch('/cases/:caseId/findings/:findingId', validate({ params: v.caseChildParams('findingId'), body: v.patchFinding }), async (req, res) => {
  await requireOwnedCase(req.user.id, req.params.caseId);
  if (!(await findingRepo.updateStatus(req.params.caseId, req.params.findingId, req.body.status))) throw notFound('Finding');
  if (req.body.status !== 'open') {
    await cases.addEvent(req.params.caseId, 'custom', `Finding marked ${req.body.status.replace('_', ' ')}`, { findingId: req.params.findingId }, true);
  }
  res.status(204).end();
});
