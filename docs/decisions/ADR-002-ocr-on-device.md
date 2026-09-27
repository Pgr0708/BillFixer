# ADR-002: OCR Is Always On-Device (Vision Framework)

**Date:** 2026-09-27
**Status:** Accepted

## Context
Medical bills contain sensitive PII (names, DOBs, insurance IDs, diagnosis context).
Sending document images to a cloud OCR service (Google Vision, AWS Textract, Azure) would require transmitting raw medical documents to a third party.

## Decision
OCR is performed exclusively on-device using Apple's Vision framework.
Only structured extracted data (provider name, amounts, line items) is sent to the backend.
Raw document images are never sent to any external service for OCR.

## Consequences
- Privacy-preserving by design (major product differentiator)
- OCR quality depends on Vision's accuracy (generally excellent for printed documents)
- No cloud OCR cost
- Slightly slower than server GPU-based OCR for very low quality images
- Cannot use specialized medical-billing fine-tuned OCR models (acceptable tradeoff)
