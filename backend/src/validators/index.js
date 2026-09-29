import { z } from 'zod';

// ── Primitives ──
const MONEY_RE = /^\d{1,8}(\.\d{1,2})?$/;
const SIGNED_MONEY_RE = /^-?\d{1,8}(\.\d{1,2})?$/;
const toMoneyString = (v) => (typeof v === 'number' ? v.toFixed(2) : String(v).trim().replace(/[$,\s]/g, ''));

export const money = z.union([z.string(), z.number()]).transform(toMoneyString)
  .refine((s) => MONEY_RE.test(s), 'Must be a non-negative amount with at most 2 decimals');
export const signedMoney = z.union([z.string(), z.number()]).transform(toMoneyString)
  .refine((s) => SIGNED_MONEY_RE.test(s), 'Must be an amount with at most 2 decimals');
const optMoney = money.nullish().transform((v) => v ?? null);
const optSignedMoney = signedMoney.nullish().transform((v) => v ?? null);

export const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD')
  .refine((s) => { const d = new Date(`${s}T00:00:00Z`); return !Number.isNaN(d.getTime()) && d.toISOString().startsWith(s); }, 'Invalid date')
  .refine((s) => s >= '1990-01-01' && s <= '2100-12-31', 'Date out of range');
const optDate = isoDate.nullish().transform((v) => v ?? null);

const text = (max) => z.string().trim().max(max);
const optText = (max) => text(max).nullish().transform((v) => (v ? v : null));
export const uuidSchema = z.string().uuid('Invalid id');
export const email = z.string().trim().toLowerCase().email('Enter a valid email').max(254);
export const password = z.string().min(8, 'Use at least 8 characters').max(128)
  .refine((p) => /[A-Za-z]/.test(p) && /\d/.test(p), 'Use at least one letter and one number');
const code = z.string().trim().toUpperCase().max(20).regex(/^[A-Z0-9.-]*$/, 'Invalid code').nullish().transform((v) => v || null);
const quantity = z.union([z.string(), z.number()]).transform((v) => String(v).trim())
  .refine((s) => /^\d{1,5}(\.\d{1,3})?$/.test(s) && Number(s) > 0, 'Quantity must be greater than 0');

// ── Params ──
export const caseParams = z.object({ caseId: uuidSchema });
export const caseChildParams = (name) => z.object({ caseId: uuidSchema, [name]: uuidSchema });
export const jobParams = z.object({ jobId: uuidSchema });
export const providerParams = z.object({ providerId: uuidSchema });

// ── Auth ──
export const appleSignIn = z.object({
  identityToken: z.string().min(20).max(5000),
  authorizationCode: z.string().max(2000).optional(),
  nonce: z.string().min(16).max(128).optional(),
  displayName: optText(120),
}).strict();
export const register = z.object({ email, password, displayName: optText(120) }).strict();
export const login = z.object({ email, password: z.string().min(1).max(128) }).strict();
export const refreshBody = z.object({ refreshToken: z.string().min(20).max(200) }).strict();
export const forgotPassword = z.object({ email }).strict();
export const resetPassword = z.object({ email, code: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code'), newPassword: password }).strict();

// ── Account ──
export const patchMe = z.object({ displayName: text(120).min(1) }).strict();
export const changeEmail = z.object({ email, currentPassword: z.string().min(1).max(128).optional() }).strict();

// ── Cases ──
export const CASE_STATUSES = ['draft', 'active', 'awaiting_response', 'resolved', 'closed'];
export const listCasesQuery = z.object({
  status: z.enum(CASE_STATUSES).optional(),
  q: text(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
});
export const createCase = z.object({
  title: text(255).min(1).optional().default('New bill'),
  billDate: optDate,
  serviceType: optText(100),
}).strict();
export const patchCase = z.object({
  title: text(255).min(1).optional(),
  status: z.enum(CASE_STATUSES).optional(),
  currentBalance: money.optional(),
  notes: text(5000).optional(),
  providerId: uuidSchema.nullable().optional(),
}).strict();

export const createDocument = z.object({
  type: z.enum(['bill', 'eob', 'gfe', 'other']),
  source: z.enum(['camera', 'pdf', 'photos']),
  pageCount: z.number().int().min(1).max(200),
  ocrConfidence: z.number().min(0).max(1).optional(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/).optional(),
}).strict();

const billLine = z.object({
  lineNumber: z.number().int().min(1).max(10_000).optional(),
  code,
  description: text(500).min(1, 'Description is required'),
  dateOfService: optDate,
  quantity: quantity.optional().default('1'),
  unitPrice: optMoney,
  totalAmount: signedMoney,
  adjustment: optSignedMoney,
  isUserEdited: z.boolean().optional().default(false),
  ocrConfidence: z.number().min(0).max(1).nullish(),
}).strict();

export const submitBill = z.object({
  documentId: uuidSchema.nullish(),
  providerId: uuidSchema.nullish(),
  providerName: text(255).min(1, 'Provider name is required'),
  providerNpi: z.string().regex(/^\d{10}$/).nullish(),
  accountNumber: optText(100),
  billDate: optDate,
  serviceDateStart: optDate,
  serviceDateEnd: optDate,
  insurerName: optText(255),
  memberIdLast4: z.string().regex(/^[A-Za-z0-9•]{1,8}$/).nullish(),
  totalCharges: optMoney,
  insurancePayment: optSignedMoney,
  adjustments: optSignedMoney,
  previousPayments: optSignedMoney,
  patientResponsibility: optMoney,
  currentBalance: optMoney,
  isItemized: z.boolean().default(false),
  ocrConfidence: z.number().min(0).max(1).nullish(),
  lineItems: z.array(billLine).max(500).default([]),
}).strict().refine((b) => !b.serviceDateStart || !b.serviceDateEnd || b.serviceDateStart <= b.serviceDateEnd,
  { message: 'Service start date must be before the end date', path: ['serviceDateEnd'] });

const eobLine = z.object({
  lineNumber: z.number().int().min(1).max(10_000).optional(),
  code,
  description: optText(500),
  dateOfService: optDate,
  billedAmount: optMoney,
  allowedAmount: optMoney,
  insurerPaid: optMoney,
  patientResponsibility: optMoney,
  networkStatus: z.enum(['in', 'out', 'unknown']).default('unknown'),
}).strict();

export const submitEob = z.object({
  documentId: uuidSchema.nullish(),
  claimNumber: optText(100),
  eobDate: optDate,
  insurerName: optText(255),
  memberIdLast4: z.string().regex(/^[A-Za-z0-9•]{1,8}$/).nullish(),
  serviceDateStart: optDate,
  serviceDateEnd: optDate,
  providerName: optText(255),
  networkStatus: z.enum(['in', 'out', 'unknown']).default('unknown'),
  billedAmount: optMoney,
  allowedAmount: optMoney,
  insurerPayment: optMoney,
  deductibleApplied: optMoney,
  copay: optMoney,
  coinsurance: optMoney,
  patientResponsibility: optMoney,
  lineItems: z.array(eobLine).max(500).default([]),
}).strict();

export const submitGfe = z.object({
  providerName: optText(255),
  estimateDate: optDate,
  totalEstimate: money,
}).strict();

// ── Analysis ──
const US_STATE = z.string().trim().toUpperCase().regex(/^[A-Z]{2}$/, 'Use a 2-letter state code');
export const analyzeBody = z.object({
  context: z.object({
    wasEmergency: z.boolean().optional(),
    hasInsurance: z.boolean().optional(),
    outOfNetwork: z.boolean().optional(),
    householdSize: z.number().int().min(1).max(20).optional(),
    annualIncome: money.optional(),
    state: US_STATE.optional(),
  }).strict().default({}),
}).strict().default({ context: {} });

export const FINDING_STATUSES = ['open', 'dismissed', 'fixed', 'partially_fixed', 'denied', 'wrong'];
export const patchFinding = z.object({ status: z.enum(FINDING_STATUSES) }).strict();

// ── Letters / scripts ──
export const LETTER_TYPES = ['itemized_bill_request', 'duplicate_dispute', 'eob_mismatch_dispute', 'cash_price_adjustment',
  'financial_assistance', 'gfe_dispute', 'insurance_appeal', 'collections_dispute', 'payment_plan_request', 'nsa_dispute'];
export const createLetter = z.object({
  type: z.enum(LETTER_TYPES).optional(),
  findingId: uuidSchema.nullish(),
  recipientName: optText(255),
  recipientType: z.enum(['provider', 'insurer', 'collections', 'other']).default('provider'),
}).strict().refine((b) => b.type || b.findingId, { message: 'Provide a letter type or a finding', path: ['type'] });
export const patchLetter = z.object({ content: z.string().min(20).max(50_000) }).strict();
export const markSent = z.object({ sentAt: z.string().datetime({ offset: true }).optional() }).strict();

export const createScript = z.object({
  findingId: uuidSchema.nullish(),
  callTarget: z.enum(['provider_billing', 'insurer', 'collections']),
  issueType: text(60).min(1),
}).strict();

// ── Deadlines / timeline / outcome ──
export const createDeadline = z.object({
  type: z.enum(['ppdr_120day', 'insurance_appeal', 'follow_up', 'fa_application', 'custom']).default('custom'),
  label: text(255).min(1),
  dueDate: isoDate,
  notifyDays: z.array(z.number().int().min(0).max(120)).max(5).optional(),
}).strict();
export const patchDeadline = z.object({
  label: text(255).min(1).optional(),
  dueDate: isoDate.optional(),
  isCompleted: z.boolean().optional(),
}).strict();
export const createNote = z.object({ label: text(500).min(1) }).strict();
export const resolveCase = z.object({
  resolution: z.enum(['full_reduction', 'partial_reduction', 'denied', 'financial_assistance', 'payment_plan', 'no_change', 'other']),
  finalBalance: money,
  notes: optText(5000),
}).strict();

// ── Reference ──
export const providerSearchQuery = z.object({ q: text(100).min(2, 'Type at least 2 characters'), state: US_STATE.optional() });
export const pricingQuery = z.object({
  codes: z.string().max(600).transform((s) => s.split(',').map((x) => x.trim().toUpperCase()).filter(Boolean))
    .refine((a) => a.length >= 1 && a.length <= 50, 'Provide 1–50 codes'),
});
export const fplQuery = z.object({
  year: z.coerce.number().int().min(1983).max(2100).optional(),
  state: US_STATE.optional(),
});
export const fplEstimateBody = z.object({
  householdSize: z.number().int().min(1).max(20),
  annualIncome: money,
  state: US_STATE.optional(),
}).strict();
export const benchmarkQuery = pricingQuery;
