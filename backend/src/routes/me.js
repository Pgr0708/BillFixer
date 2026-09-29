import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { notFound } from '../lib/errors.js';
import { invalidate } from '../lib/cache.js';
import { mapUser } from '../repositories/mappers.js';
import * as v from '../validators/index.js';
import * as users from '../repositories/userRepo.js';
import { changeEmail } from '../services/authService.js';
import { rateLimit } from '../middleware/rateLimit.js';

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

/** Change sign-in / contact email (password re-check for password accounts). */
meRoutes.patch('/me/email', rateLimit({ name: 'emailchange', windowSec: 3600, max: 10, key: (req) => req.user.id }),
  validate({ body: v.changeEmail }), async (req, res) => {
    res.json({ user: await changeEmail({ userId: req.user.id, ...req.body }) });
  });

/** Hard delete of the account and every row of medical data (FK cascades). */
meRoutes.delete('/me', async (req, res) => {
  await users.deleteUser(req.user.id);
  await invalidate('tier', req.user.id);
  res.status(204).end();
});
