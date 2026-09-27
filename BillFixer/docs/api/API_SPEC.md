# BillFixer — API Specification

> DELETE BEFORE SUBMISSION
> Base URL: https://api.billfixer.app/v1
> Auth: Bearer JWT (all endpoints unless noted)
> All amounts in USD, all dates ISO 8601

---

## Authentication

### POST /auth/apple
Apple Sign In with Identity Token.
```json
Request:
{ "identityToken": "string", "authorizationCode": "string", "displayName": "string?" }

Response 200:
{ "accessToken": "string", "refreshToken": "string", "user": { "id": "uuid", "email": "string?", "displayName": "string?" } }
```

### POST /auth/refresh
```json
Request:
{ "refreshToken": "string" }

Response 200:
{ "accessToken": "string" }
```

### DELETE /auth/session
Logout (invalidate refresh token).

---

## Cases

### GET /cases
Returns user's case list.
```json
Response 200:
{
  "cases": [{
    "id": "uuid",
    "title": "string",
    "status": "active|awaiting_response|resolved|closed",
    "providerName": "string?",
    "originalBalance": "decimal_string",
    "currentBalance": "decimal_string",
    "verifiedSavings": "decimal_string?",
    "findingCount": 0,
    "nextDeadline": { "label": "string", "dueDate": "ISO8601", "type": "string" }?,
    "createdAt": "ISO8601",
    "updatedAt": "ISO8601"
  }]
}
```

### POST /cases
Create new case.
```json
Request:
{ "title": "string?", "billDate": "date_string?", "serviceType": "string?" }

Response 201:
{ "caseId": "uuid", "uploadUrls": { "bill": "presigned_url" } }
```

### GET /cases/:caseId
Full case detail.

### PATCH /cases/:caseId
Update case (title, status, currentBalance, notes).

### DELETE /cases/:caseId
Delete case and all documents/findings/letters (hard delete).

---

## Documents

### POST /cases/:caseId/documents
Initiate document upload. Returns presigned R2 URLs.
```json
Request:
{ "type": "bill|eob|gfe", "pageCount": 3, "source": "camera|pdf|photos" }

Response 201:
{
  "documentId": "uuid",
  "uploadUrls": ["presigned_url_page_1", "presigned_url_page_2", "presigned_url_page_3"]
}
```

### POST /cases/:caseId/documents/:documentId/complete
Signal upload complete, trigger OCR.
```json
Request: {}
Response 202: { "jobId": "string", "estimatedSeconds": 15 }
```

### GET /cases/:caseId/documents/:documentId/ocr
Poll OCR status and results.
```json
Response 200:
{
  "status": "pending|processing|complete|failed",
  "pages": [{
    "pageNumber": 1,
    "confidence": 0.94,
    "blocks": [{
      "text": "string",
      "confidence": 0.97,
      "boundingBox": { "x": 0, "y": 0, "width": 0, "height": 0 }
    }]
  }]
}
```

---

## Bills & OCR Data

### POST /cases/:caseId/bill
Submit structured bill data (after user OCR review).
```json
Request:
{
  "documentId": "uuid",
  "providerName": "string",
  "accountNumber": "string?",
  "billDate": "date",
  "serviceDateStart": "date",
  "serviceDateEnd": "date",
  "insurerName": "string?",
  "totalCharges": "decimal",
  "insurancePayment": "decimal?",
  "adjustments": "decimal?",
  "patientResponsibility": "decimal",
  "currentBalance": "decimal",
  "isItemized": true,
  "lineItems": [{
    "lineNumber": 1,
    "code": "string?",
    "description": "string",
    "dateOfService": "date?",
    "quantity": "decimal",
    "unitPrice": "decimal",
    "totalAmount": "decimal",
    "adjustment": "decimal?",
    "isUserEdited": false
  }]
}
Response 201: { "billId": "uuid" }
```

### POST /cases/:caseId/eob
Same structure as bill but for EOB fields.

---

## Analysis

### POST /cases/:caseId/analyze
Trigger full analysis pipeline. Requires bill submitted. EOB optional.
```json
Request: { "billId": "uuid", "eobId": "uuid?" }
Response 202: { "jobId": "string", "estimatedSeconds": 30 }
```

### GET /cases/:caseId/analysis/status
Poll analysis status.
```json
Response 200:
{
  "status": "queued|running|complete|failed",
  "progress": 0.6,
  "steps": [
    { "key": "arithmetic", "label": "Checking the math...", "status": "complete" },
    { "key": "eob_reconcile", "label": "Comparing with your EOB...", "status": "running" },
    { "key": "pricing", "label": "Looking up hospital prices...", "status": "pending" },
    { "key": "rights", "label": "Checking your rights...", "status": "pending" }
  ]
}
```

### GET /cases/:caseId/findings
Get all findings for a case.
```json
Response 200:
{
  "findings": [{
    "id": "uuid",
    "type": "string",
    "severity": "strong|likely|possible|informational",
    "confidence": "high|medium|low",
    "title": "string",
    "explanation": "string",
    "amountFlagged": "decimal?",
    "amountReference": "decimal?",
    "amountDifference": "decimal?",
    "recommendedAction": "string?",
    "evidence": [{
      "sourceType": "string",
      "label": "string",
      "value": "string?",
      "url": "string?"
    }],
    "status": "open|dismissed|fixed|partially_fixed|denied|wrong"
  }]
}
```

### PATCH /cases/:caseId/findings/:findingId
Update finding status (user feedback).
```json
Request: { "status": "wrong|dismissed|fixed|partially_fixed|denied" }
```

---

## Letters

### POST /cases/:caseId/letters
Generate a letter.
```json
Request:
{
  "type": "itemized_bill_request|duplicate_dispute|eob_mismatch_dispute|cash_price_adjustment|financial_assistance|gfe_dispute|insurance_appeal|payment_plan_request",
  "findingId": "uuid?",
  "recipientName": "string?",
  "recipientType": "provider|insurer|collections"
}
Response 202: { "jobId": "string", "estimatedSeconds": 20 }
```

### GET /cases/:caseId/letters/:letterId
Get letter content.
```json
Response 200:
{
  "id": "uuid",
  "type": "string",
  "content": "string",
  "recipientName": "string?",
  "version": 1,
  "createdAt": "ISO8601"
}
```

### PATCH /cases/:caseId/letters/:letterId
Update letter content (user edits).

### POST /cases/:caseId/letters/:letterId/mark-sent
Mark letter as sent.
```json
Request: { "sentAt": "ISO8601?" }
```

---

## Phone Scripts

### POST /cases/:caseId/scripts
Generate phone script.
```json
Request:
{
  "findingId": "uuid?",
  "callTarget": "provider_billing|insurer|collections",
  "issueType": "string"
}
Response 202: { "jobId": "string" }
```

### GET /cases/:caseId/scripts/:scriptId
Get script content with decision tree structure.
```json
Response 200:
{
  "id": "uuid",
  "openingStatement": "string",
  "branches": [{
    "trigger": "string",
    "response": "string",
    "followUp": "string?",
    "childBranches": []
  }],
  "postCallChecklist": ["string"]
}
```

---

## Hospital / Provider

### GET /providers/search?q=:query&state=:state
Search hospital directory.
```json
Response 200:
{
  "results": [{
    "id": "uuid",
    "name": "string",
    "facilityName": "string?",
    "city": "string",
    "state": "string",
    "taxStatus": "nonprofit|for_profit|government|unknown",
    "hasMRF": true,
    "hasFAP": true
  }]
}
```

### GET /providers/:providerId/pricing?codes=:code1,:code2
```json
Response 200:
{
  "providerId": "uuid",
  "providerName": "string",
  "effectiveDate": "date",
  "records": [{
    "code": "string",
    "description": "string",
    "cashPrice": "decimal?",
    "grossCharge": "decimal?",
    "minNegotiatedRate": "decimal?",
    "maxNegotiatedRate": "decimal?",
    "medianNegotiatedRate": "decimal?"
  }]
}
```

### GET /providers/:providerId/financial-assistance
```json
Response 200:
{
  "providerId": "uuid",
  "taxStatus": "nonprofit",
  "fapUrl": "string?",
  "applicationUrl": "string?",
  "incomeThresholdFpl": 300.0,
  "freeCareThresholdFpl": 200.0,
  "requiredDocs": ["string"],
  "allowsRetroactive": true
}
```

---

## Subscription

### GET /subscription/status
```json
Response 200:
{
  "tier": "free|premium",
  "productId": "string?",
  "expiresAt": "ISO8601?",
  "isInGracePeriod": false
}
```

### POST /subscription/validate
Validate App Store receipt (called after StoreKit purchase).
```json
Request: { "receiptData": "base64_string", "transactionId": "string" }
Response 200: { "tier": "premium", "expiresAt": "ISO8601" }
```

---

## Deadlines

### GET /cases/:caseId/deadlines
### POST /cases/:caseId/deadlines
### PATCH /cases/:caseId/deadlines/:deadlineId
### DELETE /cases/:caseId/deadlines/:deadlineId

---

## User / Account

### GET /me
### PATCH /me
### DELETE /me
(Hard deletes all user data — cases, documents, findings, letters, events)

---

## Error Format

All errors follow:
```json
{
  "error": {
    "code": "ANALYSIS_FAILED",
    "message": "Human-readable message",
    "details": {}
  }
}
```

| HTTP Status | Meaning |
|---|---|
| 400 | Invalid request body / missing required fields |
| 401 | Missing or invalid auth token |
| 402 | Subscription required for this feature |
| 403 | Forbidden (accessing another user's resource) |
| 404 | Resource not found |
| 409 | Conflict (e.g. duplicate submission) |
| 422 | Validation error (field-level errors in details) |
| 429 | Rate limited |
| 500 | Server error |
| 503 | Service temporarily unavailable |
