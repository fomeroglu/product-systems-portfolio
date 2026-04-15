# Logistics Platform — API Contract

This folder contains the v1 API contract for a B2B SaaS platform built around decoupled asset classes, programmable trust, and event-driven payment eligibility.

These artifacts are reference implementations demonstrating PM-level API design thinking — contract-first design, geofence validation, idempotency patterns, and computed projections. They reflect real patterns from operational work, genericized for portfolio use. No proprietary data or company-specific information is included.

---

## What's in here

| File | What it is |
|---|---|
| `API_Contract_v1.md` | Human-readable spec — design decisions, request/response examples, error codes, tradeoffs |
| `openapi.yaml` | Machine-readable OpenAPI 3.0 spec — import directly into Postman or Swagger UI |

---

## The three endpoints

### POST /scan-events
Records a verified physical presence event for a handling unit.

The most critical endpoint in the system. Every scan event is immutable proof that a physical event happened at a verified location. A 6-step pipeline runs before any row is inserted — authentication, event type validation, entity validation, geofence check, idempotency check, and finally insert + status update.

**Key design decisions:**
- Geofence validation is a hard fail — GPS outside the zone boundary returns 422, never a warning. Trust is enforced at the API layer, not the UI.
- Composite idempotency key over UUID — scanning devices in low-connectivity environments can't reliably generate random UUIDs. A deterministic composite key (device + event + timestamp) is retry-safe without requiring UUID generation capability.
- Geofence runs before idempotency — you cannot retry past a location failure.

### GET /capacity-tokens
Returns available capacity for the open blind board.

Suppliers list capacity without exposing their physical address. Zone name and ZIP are visible. Address is always null until a transaction is confirmed. This is enforced at the API response layer — not just the UI — so any API consumer gets the same behavior regardless of client.

**Key design decisions:**
- Address withheld at the API layer — UI enforcement alone is bypassable by any developer with API access. The guarantee has to live in the response.
- Cursor-based pagination over offset — capacity searches can return large result sets. Cursor-based pagination is stable under concurrent inserts; offset pagination drifts when new rows are added between pages.

### GET /handling-unit-groups/:id/eligibility
Computes payment eligibility for a handling unit group.

Payment eligibility is a **projection** — computed in real time from the immutable scan event log. It is never stored as a field on the group record.

**Key design decisions:**
- Computed, not stored — storing `eligible: true/false` creates two sources of truth. If a scan event is added retroactively (dispute resolution, offline device sync), the stored flag becomes stale. Computing from the event log means eligibility is always consistent with the actual record.
- Single exception blocks the group — one unresolved exception on any unit holds the entire group's payment. This forces resolution before payment flows, creating an incentive to close exceptions quickly.

---

## Payment model

Payment is triggered by verifiable scan events — not by manual approval.

- `PickedUpByConsignee` — smart contract trigger for moving assets
- `FacilityCheckOut` — smart contract trigger for stationary assets

This means the system can compute exactly what was delivered, what was not, and what is disputed — from the immutable event log alone. No manual reconciliation.

---

## Idempotency pattern

All write endpoints are idempotent. The pattern:

```
Client generates idempotency_key → sends request
Server checks: seen this key before?
  YES → return original response, do not process again
  NO  → process + store key + return new response
```

Recommended key format:
```
{handling_unit_id}-{event_type_code}-{occurred_at_utc}
```

Deterministic — the same physical event always produces the same key — making it safe for devices that cannot generate reliable random UUIDs.

---

## How to use these files

**In Postman:**
1. Open Postman → Import
2. Select `openapi.yaml`
3. Postman generates a full collection with all endpoints, parameters, and example payloads

**In Swagger UI:**
Paste the contents of `openapi.yaml` into `https://editor.swagger.io` to render interactive documentation.
