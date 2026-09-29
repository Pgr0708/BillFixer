import { toIso } from '../lib/time.js';

/** Row → API shapes (camelCase, decimals as strings, ISO dates). */
const dec = (v) => (v === null || v === undefined ? null : String(v));
const json = (v) => (v === null || v === undefined ? null : typeof v === 'string' ? JSON.parse(v) : v);

export const mapUser = (u) => u && ({
  id: u.id,
  email: u.email ?? null,
  displayName: u.display_name ?? null,
  hasPassword: Boolean(u.has_password),
  signInMethod: u.apple_sub ? 'apple' : 'email',
  createdAt: toIso(u.created_at),
});

export const mapCaseSummary = (c) => ({
  id: c.id,
  title: c.title,
  status: c.status,
  providerName: c.provider_name ?? null,
  serviceType: c.service_type ?? null,
  billDate: c.bill_date ?? null,
  originalBalance: dec(c.original_balance),
  currentBalance: dec(c.current_balance),
  verifiedSavings: dec(c.verified_savings),
  potentialSavings: dec(c.potential_savings),
  findingCount: Number(c.finding_count ?? 0),
  nextDeadline: json(c.next_deadline),
  lastAnalyzedAt: toIso(c.last_analyzed_at),
  createdAt: toIso(c.created_at),
  updatedAt: toIso(c.updated_at),
});

export const mapEvidence = (e) => ({
  sourceType: e.source_type,
  label: e.label,
  value: e.value ?? null,
  url: e.url ?? null,
});

export const mapFinding = (f, evidence = []) => ({
  id: f.id,
  type: f.type,
  severity: f.severity,
  confidence: f.confidence,
  title: f.title,
  explanation: f.explanation,
  whatYouCanDo: f.what_you_can_do ?? null,
  counterCase: f.counter_case ?? null,
  amountFlagged: dec(f.amount_flagged),
  amountReference: dec(f.amount_reference),
  amountDifference: dec(f.amount_difference),
  recommendedAction: f.recommended_action ?? null,
  deadlineDate: f.deadline_date ?? null,
  status: f.status,
  locked: false,
  evidence: evidence.map(mapEvidence),
});

export const mapLetter = (l) => ({
  id: l.id,
  caseId: l.case_id,
  findingId: l.finding_id ?? null,
  type: l.type,
  subject: l.subject ?? null,
  content: l.content,
  recipientName: l.recipient_name ?? null,
  recipientType: l.recipient_type,
  version: l.version,
  isFallback: Boolean(l.is_fallback),
  sentAt: toIso(l.sent_at),
  createdAt: toIso(l.created_at),
  updatedAt: toIso(l.updated_at),
});

export const mapScript = (s) => ({
  id: s.id,
  caseId: s.case_id,
  findingId: s.finding_id ?? null,
  callTarget: s.call_target,
  issueType: s.issue_type,
  isFallback: Boolean(s.is_fallback),
  createdAt: toIso(s.created_at),
  ...json(s.content),
});

export const mapDeadline = (d) => ({
  id: d.id,
  type: d.type,
  label: d.label,
  dueDate: d.due_date,
  isCompleted: Boolean(d.is_completed),
  completedAt: toIso(d.completed_at),
  notifyDays: json(d.notify_days) ?? [],
});

export const mapEvent = (e) => ({
  id: e.id,
  type: e.type,
  label: e.label,
  metadata: json(e.metadata),
  isUserLog: Boolean(e.is_user_log),
  occurredAt: toIso(e.occurred_at),
});

export const mapJob = (j) => ({
  jobId: j.id,
  type: j.type,
  status: j.status,
  progress: Number(j.progress),
  steps: json(j.steps) ?? [],
  resultType: j.result_type ?? null,
  resultId: j.result_id ?? null,
  errorCode: j.error_code ?? null,
  updatedAt: toIso(j.updated_at),
});

export const mapProvider = (p) => ({
  id: p.id,
  name: p.name,
  facilityName: p.facility_name ?? null,
  address: p.address ?? null,
  city: p.city ?? null,
  state: p.state ?? null,
  zip: p.zip ?? null,
  phone: p.phone ?? null,
  hospitalType: p.hospital_type ?? null,
  taxStatus: p.tax_status,
  hasMRF: Boolean(p.mrf_url),
  hasFAP: Boolean(p.fap_url) || p.tax_status === 'nonprofit',
});
