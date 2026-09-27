# ADR-001: LLM Is Never Called Directly from iOS

**Date:** 2026-09-27
**Status:** Accepted

## Context
The app requires LLM capabilities to generate human-readable explanations and draft letters.
Calling LLM APIs directly from the iOS app would expose API keys, increase attack surface, and allow hallucinations to reach users without server-side validation.

## Decision
All LLM calls go exclusively through the backend API.
iOS never holds or uses any LLM API key.
The backend validates all LLM responses against strict schemas and prohibited-phrase filters before returning to iOS.

## Consequences
- Increased backend complexity (worker queues required)
- Network dependency for LLM-dependent features (offline analysis not possible for LLM steps)
- Full control over model selection, cost, and output safety
- API secrets never at risk on device
