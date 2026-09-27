# ADR-004: All Monetary Values Use Decimal, Never Float

**Date:** 2026-09-27
**Status:** Accepted

## Context
Floating-point arithmetic introduces rounding errors that are unacceptable for financial calculations.
Example: 3 * 0.1 = 0.30000000000000004 in IEEE 754.

## Decision
- iOS: All money values use `Decimal` type (Foundation)
- Backend: All money values use `DECIMAL(10,2)` in MySQL (never FLOAT)
- API: All money values transmitted as decimal strings ("690.00"), never floats
- Arithmetic: Use `Decimal` arithmetic methods, never `Double` or `Float` conversions
- Tolerance for comparison: $0.01 tolerance where rounding is expected (EOB comparisons)

## Consequences
- Slightly more verbose Swift code (Decimal arithmetic is less ergonomic than Double)
- Correct financial arithmetic guaranteed
- No floating-point surprises in bill math verification
