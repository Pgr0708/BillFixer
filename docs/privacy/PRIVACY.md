# BillFixer — Privacy & Security

> DELETE BEFORE SUBMISSION

---

## Privacy Classification

### Sensitive Data (Class S — highest protection)
- Medical bill images / PDFs
- EOB images / PDFs
- Patient names (derived from documents)
- Insurance member IDs
- Diagnosis or procedure context
- Provider account numbers

**Handling:**
- OCR on-device only (Vision framework — never sent to cloud for OCR)
- Documents stored in Cloudflare R2 with server-side encryption (SSE-C)
- Presigned URLs for access (1 hour TTL)
- PII redacted before LLM processing
- Auto-deleted after configurable period (default: 90 days post-close)
- Hard delete (not soft delete) on user request

### Personal Data (Class P)
- Email, display name
- Apple ID
- Subscription status
- Case titles, provider names (user-labeled)

**Handling:**
- Stored in MySQL with field-level encryption for PII
- Not included in analytics events
- Exported with account data export

### Analytics Data (Class A — non-sensitive)
- Feature usage events (no content)
- Screen views
- Subscription events
- Error events

**Handling:**
- No names, amounts, or document content in events
- Event keys are generic: "analysis_started", "letter_generated" (no finding details)

---

## On-Device Processing Guarantee

The following never leaves the device to a cloud service:

| Operation | Where it runs |
|---|---|
| Camera capture | On-device |
| Image preprocessing | On-device |
| OCR text extraction | Vision framework, on-device |
| Temporary image storage | App sandbox, deleted after |
| OCR confidence scoring | On-device |

After OCR is complete on-device, only the **structured extracted data** (provider name, amounts, line items) is sent to the backend — never the raw document image (unless user explicitly stores it for their case).

---

## Data Retention Policy

| Data Type | Retention | Trigger |
|---|---|---|
| Documents (active case) | Duration of case + 90 days | User can extend |
| Documents (closed case) | 90 days post-close | Auto-delete |
| Findings, letters, events | Same as case | Deleted with case |
| Analytics events | 90 days rolling | Auto-purge |
| Server logs (non-sensitive) | 30 days | Auto-purge |
| Subscription records | 7 years (tax/legal) | Manual review required |
| User account | Until deletion request | User-controlled |

---

## Data Deletion

### Account Deletion Flow
```
User requests → Immediate soft delete (account inaccessible)
→ Hard delete queue triggered:
   - All documents deleted from R2
   - All cases, findings, letters deleted from MySQL
   - All analytics events deleted
   - User record hard deleted
→ Completion within 24 hours
→ Confirmation email sent
```

### Right to Erasure (CCPA/General)
- Full CCPA-aligned deletion flow above
- User can request via Settings > Delete Account
- No "cooling off" period — deletion is immediate upon confirmation

---

## Encryption

| Layer | Method |
|---|---|
| Transit (iOS → API) | TLS 1.3 minimum |
| Storage (R2 documents) | SSE-C (customer-managed key) |
| Database PII fields | AES-256 at field level |
| Keychain (iOS) | Hardware-backed, whenUnlockedThisDeviceOnly |
| JWTs | RS256 signed |
| Refresh tokens | Opaque, stored hashed |

---

## Security Rules

### API Security
- Rate limiting: 100 requests/minute per user
- Document upload size limit: 50MB
- File type validation (only image/jpeg, image/png, application/pdf)
- Virus scanning on document upload (ClamAV or equivalent)
- Input validation on all endpoints (Zod schemas on Node.js)
- SQL injection prevention: parameterized queries only (Knex.js or Prisma)
- XSS prevention: no HTML rendering of user content

### Authentication Security
- JWT access tokens: 15 minute expiry
- Refresh tokens: 30 day expiry, single-use rotation
- Failed auth attempts: exponential backoff + lock after 10 failures
- Apple Sign In: server-side token validation (never trust client-side only)

### iOS Security
- Certificate pinning in production
- Jailbreak detection (advisory, not blocking)
- Keychain with biometric protection for sensitive data
- No sensitive data in UserDefaults
- No sensitive data in iCloud backup (NSURLIsExcludedFromBackupKey)
- Debug logging stripped in release builds
- No secrets in source code or Info.plist

---

## Privacy Disclosure (What We Tell Users)

Bill Fixer collects:
- Account information (email or Apple ID) — for authentication
- Medical billing documents — to perform analysis (stored securely, user-controlled deletion)
- Usage patterns (anonymized) — to improve the app

Bill Fixer does NOT:
- Sell user data to any third party
- Share medical data with advertisers
- Use medical data to train AI models
- Access user health records or insurance accounts
- Share data with medical providers or insurers

---

## App Store Privacy Labels

### Data Linked to You
- Contact Info: Email (account)
- Usage Data: App interactions

### Data Not Linked to You
- Analytics: Anonymized usage (if used)

### Data NOT collected
- Health & Fitness data
- Financial Info (we see numbers in bills but don't transmit as "financial info")
- Contacts
- Location
- Search history

---

## HIPAA Positioning

Bill Fixer is a **consumer financial tool**, not a healthcare provider or business associate.

- We do not receive PHI from covered entities
- Users voluntarily upload their own documents
- We are not acting as a HIPAA Business Associate
- However, we apply HIPAA-grade security practices voluntarily:
  - Encryption at rest and in transit
  - Minimum necessary access
  - Audit logging
  - Breach response plan

**Legal positioning:** Consumer financial billing assistant. FDA consumer exemption applies.
Do not market as "HIPAA compliant" — this implies BA status which creates obligations.
