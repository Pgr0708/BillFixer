import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { config } from '../config/index.js';
import * as v from '../validators/index.js';
import * as auth from '../services/authService.js';

export const authRoutes = Router();
const strict = rateLimit({ name: 'auth', windowSec: 900, max: config.limits.authPer15Min });
const refreshLimit = rateLimit({ name: 'refresh', windowSec: 900, max: 60 });
const ua = (req) => req.get('user-agent');

authRoutes.post('/auth/apple', strict, validate({ body: v.appleSignIn }), async (req, res) => {
  res.json(await auth.signInWithApple({ ...req.body, userAgent: ua(req) }));
});
authRoutes.post('/auth/register', strict, validate({ body: v.register }), async (req, res) => {
  res.status(201).json(await auth.register({ ...req.body, userAgent: ua(req) }));
});
authRoutes.post('/auth/login', strict, validate({ body: v.login }), async (req, res) => {
  res.json(await auth.login({ ...req.body, userAgent: ua(req) }));
});
authRoutes.post('/auth/refresh', refreshLimit, validate({ body: v.refreshBody }), async (req, res) => {
  res.json(await auth.refresh({ ...req.body, userAgent: ua(req) }));
});
authRoutes.delete('/auth/session', refreshLimit, validate({ body: v.refreshBody }), async (req, res) => {
  await auth.logout(req.body);
  res.status(204).end();
});
authRoutes.post('/auth/password/forgot', strict, validate({ body: v.forgotPassword }), async (req, res) => {
  await auth.requestPasswordReset(req.body);
  res.status(202).json({ message: 'If an account exists for that email, a 6-digit code is on its way.' });
});
authRoutes.post('/auth/password/reset', strict, validate({ body: v.resetPassword }), async (req, res) => {
  res.json(await auth.resetPassword({ ...req.body, userAgent: ua(req) }));
});
