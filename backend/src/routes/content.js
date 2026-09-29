import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { requirePremium } from '../middleware/auth.js';
import { rateLimit, byUserOrIp } from '../middleware/rateLimit.js';
import { idempotency } from '../middleware/idempotency.js';
import { notFound } from '../lib/errors.js';
import { config } from '../config/index.js';
import { requireOwnedCase } from '../services/caseService.js';
import { requestLetter, requestScript } from '../services/contentService.js';
import { SCRIPT_LIBRARY } from '../services/scriptService.js';
import { mapJob } from '../repositories/mappers.js';
import * as jobs from '../repositories/jobRepo.js';
import * as v from '../validators/index.js';

export const contentRoutes = Router();
const llmLimit = rateLimit({ name: 'llm', windowSec: 3600, max: config.limits.llmPerHour, key: byUserOrIp });

contentRoutes.post('/cases/:caseId/letters', requirePremium('dispute letters'), llmLimit,
  validate({ params: v.caseParams, body: v.createLetter }), idempotency, async (req, res) => {
    await requireOwnedCase(req.user.id, req.params.caseId);
    res.status(202).json(await requestLetter(req.user.id, req.params.caseId, req.body));
  });

contentRoutes.post('/cases/:caseId/scripts', requirePremium('phone scripts'), llmLimit,
  validate({ params: v.caseParams, body: v.createScript }), idempotency, async (req, res) => {
    await requireOwnedCase(req.user.id, req.params.caseId);
    res.status(202).json(await requestScript(req.user.id, req.params.caseId, req.body));
  });

/** Poll a letter/script/analysis job. */
contentRoutes.get('/jobs/:jobId', validate({ params: v.jobParams }), async (req, res) => {
  const job = await jobs.getOwned(req.user.id, req.params.jobId);
  if (!job) throw notFound('Job');
  res.set('Cache-Control', 'no-store');
  res.json(mapJob(job));
});

/** Scripts library (Learn tab). The opening + first branch are free; the full tree is premium. */
contentRoutes.get('/scripts/library', async (req, res) => {
  const premium = (await req.tier()).tier === 'premium';
  res.json({
    scripts: SCRIPT_LIBRARY.map((s) => ({
      ...s,
      locked: !premium,
      script: premium ? s.script : { ...s.script, branches: s.script.branches.slice(0, 1), postCallChecklist: [] },
    })),
  });
});
