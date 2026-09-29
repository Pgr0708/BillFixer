import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { notFound } from '../lib/errors.js';
import { invalidate } from '../lib/cache.js';
import { mapUser } from '../repositories/mappers.js';
import * as v from '../validators/index.js';
import * as users from '../repositories/userRepo.js';

export const meRoutes = Router();

meRoutes.get('/me', async (req, res) => {
  const user = await users.findById(req.user.id);
  if (!user) throw notFound('Account');
  res.json({ user: mapUser(user), subscription: await req.tier() });
});

meRoutes.patch('/me', validate({ body: v.patchMe }), async (req, res) => {
  await users.updateDisplayName(req.user.id, req.body.displayName);
  res.json({ user: mapUser(await users.findById(req.user.id)) });
});

/** Hard delete of the account and every row of medical data (FK cascades). */
meRoutes.delete('/me', async (req, res) => {
  await users.deleteUser(req.user.id);
  await invalidate('tier', req.user.id);
  res.status(204).end();
});
