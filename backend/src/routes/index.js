import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { authRoutes } from './auth.js';
import { meRoutes } from './me.js';
import { caseRoutes } from './cases.js';
import { analysisRoutes } from './analysis.js';
import { contentRoutes } from './content.js';
import { referenceRoutes } from './reference.js';
import { subscriptionRoutes, webhookRoutes } from './subscription.js';

export const v1 = Router();

// Public
v1.use(authRoutes);
v1.use(webhookRoutes);

// Everything below requires a valid access token
v1.use(requireAuth);
v1.use(meRoutes);
v1.use(caseRoutes);
v1.use(analysisRoutes);
v1.use(contentRoutes);
v1.use(referenceRoutes);
v1.use(subscriptionRoutes);
