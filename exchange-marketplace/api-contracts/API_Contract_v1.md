# Exchange Marketplace — API Contract v1

**Version:** 1.0.0  
**Status:** v1 Reference Implementation  
**Last updated:** 2026-04

---

## Design Philosophy

This API is **contract-first** — the spec was written before any implementation. Every endpoint is designed from the consumer's perspective: what does the driver app need? What does the operator dashboard need? What does the payment system need?

Three design principles govern every endpoint:

**1. Immutability over updates**  
Scan events are never updated or deleted. The append-only event log is the source of truth. Projections (like `HandlingUnit.status`) are derived from events — never directly mutated via API.

**2. Hard-fail over silent degradation**  
If a scan event's GPS coordinates fall outside the zone geofence, the request is rejected with `422`. The system never silently accepts bad data and corrects it later. Trust is built on verified physical presence, not on assumed proximity.

**3. Idempotency by default**  
Every write endpoint is idempotent. Retry-safe by design. A driver who loses connectivity mid-scan and retries will never create duplicate records.

---

## Authentication

All endpoints require a valid API key passed in the request header.

```
Authorization: Bearer <api_key>
```

API keys are scoped by role:
- `driver` — can submit scan events only
- `operator` — can submit scan events + read eligibility
- `admin` — full access

A valid key with insufficient scope returns `403 Forbidden`.

---

## Base URL

```
https://api.exchange.io/v1
```

---

## Endpoints

### 1. POST /scan-events

Records a verified physical presence event for a handling unit.

**This is the most critical endpoint in the system.** Every scan event is immutable proof. The geofence validation ensures the record represents real physical presence — not remote submission.

#### The 6-Step Pipeline

Before a scan event row is inserted, the API executes six sequential validation steps. A failure at any step rejects the request — nothing is partially written.

```
Step 1: Authenticate API key
Step 2: Validate event_type_code exists in SCAN_EVENT_TYPES
Step 3: Validate handling_unit_id exists in HANDLING_UNITS
Step 4: Geofence validation — GPS coordinates must fall within zone radius
Step 5: Idempotency check — reject duplicate (handling_unit_id + event_type_code + occurred_at_utc)
Step 6: Insert SCAN_EVENTS row + update HANDLING_UNITS.status + trigger materialization if first scan
```

#### Why this order matters

Geofence check (Step 4) runs before idempotency (Step 5). This means a retry of a geofence-failed request will also fail — you cannot retry your way past a location validation failure. Idempotency only protects against network retries of valid requests.

#### Request

```http
POST /v1/scan-events
Authorization: Bearer <api_key>
Content-Type: application/json
```

```json
{
  "handling_unit_id": 1042,
  "event_type_code": "PickedUpAtOrigin",
  "occurred_at_utc": "2026-04-13T14:30:00Z",
  "zone_id": 7,
  "lat": 29.7601,
  "lng": -95.3701,
  "user_id": 88,
  "idempotency_key": "hu-1042-PickedUpAtOrigin-20260413T143000Z"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `handling_unit_id` | integer | ✅ | FK → HANDLING_UNITS.id |
| `event_type_code` | string | ✅ | FK → SCAN_EVENT_TYPES.code |
| `occurred_at_utc` | ISO 8601 | ✅ | When the physical event happened |
| `zone_id` | integer | ✅ | FK → ZONES.id — which zone this scan is at |
| `lat` | float | ✅ | Driver GPS latitude |
| `lng` | float | ✅ | Driver GPS longitude |
| `user_id` | integer | ✅ | Who performed the scan |
| `idempotency_key` | string | ✅ | Unique key to make retries safe |

#### Success Response — `201 Created`

```json
{
  "scan_event_id": 5509,
  "handling_unit_id": 1042,
  "event_type_code": "PickedUpAtOrigin",
  "occurred_at_utc": "2026-04-13T14:30:00Z",
  "zone_id": 7,
  "status": "recorded",
  "handling_unit_status": "IN_TRANSIT",
  "materialized": true
}
```

`materialized: true` means this was the first scan event on this handling unit — the unit is now physically verified.

#### Idempotent Retry — `200 OK`

If the same `idempotency_key` is submitted again, the original response is returned. No new row is created.

```json
{
  "scan_event_id": 5509,
  "status": "already_recorded",
  "idempotent": true
}
```

#### Error Responses

**`401 Unauthorized`** — missing or invalid API key
```json
{ "error_code": "INVALID_API_KEY", "message": "API key missing or invalid" }
```

**`403 Forbidden`** — valid key, insufficient scope
```json
{ "error_code": "INSUFFICIENT_SCOPE", "message": "This key does not have scan event write access" }
```

**`404 Not Found`** — handling_unit_id or zone_id does not exist
```json
{ "error_code": "RESOURCE_NOT_FOUND", "message": "handling_unit_id 1042 not found" }
```

**`409 Conflict`** — event_type_code not valid
```json
{ "error_code": "INVALID_EVENT_TYPE", "message": "Event type 'ArrivedAtMoon' does not exist in SCAN_EVENT_TYPES" }
```

**`422 Unprocessable — OUTSIDE_GEOFENCE`** — GPS coordinates outside zone boundary
```json
{
  "error_code": "OUTSIDE_GEOFENCE",
  "message": "Scan location falls outside the permitted zone boundary",
  "submitted_lat": 29.7601,
  "submitted_lng": -95.3701,
  "zone_center_lat": 29.9501,
  "zone_center_lng": -95.3698,
  "distance_m": 2140,
  "allowed_radius_m": 200
}
```

The `distance_m` vs `allowed_radius_m` breakdown is intentional — it gives the driver app enough information to surface a useful error message ("You are 2.1km from the zone — move closer and retry") without exposing the zone's exact address.

**`500 Internal Server Error`**
```json
{ "error_code": "SERVER_ERROR", "message": "An unexpected error occurred", "request_id": "req_xyz789" }
```

---

### 2. GET /capacity-tokens

Returns available capacity tokens for the open blind board.

**The blind board rule:** zone name and ZIP are visible. Physical address is never returned until a transaction is confirmed. This preserves supplier confidentiality while enabling buyer discovery.

#### Request

```http
GET /v1/capacity-tokens?zip5=77002&context_type=STATIONARY&available_from=2026-04-15
Authorization: Bearer <api_key>
```

| Parameter | Type | Required | Description |
|---|---|---|---|
| `zip5` | string | ✅ | 5-digit ZIP to search near |
| `context_type` | enum | ✅ | `MOVING` or `STATIONARY` |
| `available_from` | date | ❌ | Filter tokens available from this date |
| `available_to` | date | ❌ | Filter tokens available until this date |
| `cursor` | string | ❌ | Pagination cursor from previous response |
| `limit` | integer | ❌ | Results per page. Default: 20. Max: 100 |

#### Success Response — `200 OK`

```json
{
  "data": [
    {
      "id": "ct_abc123",
      "context_type": "STATIONARY",
      "zone_name": "Houston South Terminal",
      "zip5": "77002",
      "address": null,
      "qty_available": 14,
      "price_cents": 4500,
      "currency": "USD",
      "available_from": "2026-04-15T00:00:00Z",
      "available_to": "2026-04-22T00:00:00Z",
      "status": "AVAILABLE"
    }
  ],
  "pagination": {
    "cursor": "cur_xyz456",
    "has_more": true,
    "total_count": 47
  }
}
```

`address: null` is deliberate — the physical address is withheld until the buyer confirms a transaction. This is the blind board rule enforced at the API response layer, not just the UI layer.

#### Error Responses

**`400 Bad Request`** — missing required parameters
```json
{ "error_code": "MISSING_PARAMETER", "message": "zip5 is required" }
```

**`404 Not Found`** — no available tokens match the query
```json
{ "error_code": "NO_RESULTS", "message": "No available capacity tokens found for ZIP 77002" }
```

---

### 3. GET /handling-unit-groups/:id/eligibility

Computes payment eligibility for a handling unit group.

**This is a projection, not a stored value.** Eligibility is computed in real time by querying the scan event log. It is never stored directly — it is always derived from facts. This means eligibility is always consistent with the actual event record, and can be recomputed if business rules change.

#### Payment Eligibility Rules

A group is eligible for payment when ALL of the following are true:

1. All `HandlingUnits` in the group have status `DELIVERED` or `EXCEPTION (written off)`
2. No `HandlingUnit` has an open (unresolved) `EXCEPTION` status
3. The group has at least one `PickedUpByConsignee` or `FacilityCheckOut` scan event

A single open exception blocks the entire group's payment finalization.

#### Request

```http
GET /v1/handling-unit-groups/204/eligibility
Authorization: Bearer <api_key>
```

#### Success Response — `200 OK` (eligible)

```json
{
  "group_id": 204,
  "group_status": "COMPLETED",
  "eligible": true,
  "units": [
    { "id": 1042, "status": "DELIVERED", "payment_trigger_event": "PickedUpByConsignee" },
    { "id": 1043, "status": "DELIVERED", "payment_trigger_event": "PickedUpByConsignee" },
    { "id": 1044, "status": "DELIVERED", "payment_trigger_event": "PickedUpByConsignee" }
  ],
  "blocking_conditions": []
}
```

#### Success Response — `200 OK` (not eligible)

```json
{
  "group_id": 205,
  "group_status": "PARTIALLY_COMPLETED",
  "eligible": false,
  "units": [
    { "id": 1045, "status": "DELIVERED", "payment_trigger_event": "PickedUpByConsignee" },
    { "id": 1046, "status": "EXCEPTION", "payment_trigger_event": null },
    { "id": 1047, "status": "DELIVERED", "payment_trigger_event": "PickedUpByConsignee" }
  ],
  "blocking_conditions": [
    {
      "unit_id": 1046,
      "reason": "OPEN_EXCEPTION",
      "message": "Unit 1046 has an unresolved exception. Payment is held until the exception is resolved or written off."
    }
  ]
}
```

#### Error Responses

**`404 Not Found`**
```json
{ "error_code": "GROUP_NOT_FOUND", "message": "Handling unit group 204 not found" }
```

**`403 Forbidden`** — caller does not have access to this group
```json
{ "error_code": "ACCESS_DENIED", "message": "Your organization does not have access to group 204" }
```

---

## Idempotency — How It Works

Idempotency keys protect against duplicate records caused by network retries. The pattern:

1. Client generates a unique `idempotency_key` before sending the request
2. Server checks if it has seen this key before
3. If yes: return the original response, do not process again
4. If no: process normally, store the key + response

**For scan events**, the recommended idempotency key format is:
```
{handling_unit_id}-{event_type_code}-{occurred_at_utc}
```

This is a composite key rather than a client-generated UUID because scanning devices in low-connectivity logistics environments may not have reliable random number generation. The composite key is deterministic — the same physical event always produces the same key.

**Why this matters in practice:**  
A driver scans a package at a loading dock. The request is sent. The truck hits a dead zone — no response received. The app retries. Without idempotency, two scan events are created for the same physical moment. With idempotency, the second request returns the first response silently. The event log stays clean.

---

## Error Code Reference

| Code | HTTP Status | Meaning |
|---|---|---|
| `INVALID_API_KEY` | 401 | Missing or malformed API key |
| `INSUFFICIENT_SCOPE` | 403 | Key valid but wrong permissions |
| `ACCESS_DENIED` | 403 | Org does not own this resource |
| `RESOURCE_NOT_FOUND` | 404 | Entity ID does not exist |
| `NO_RESULTS` | 404 | Query returned no matches |
| `INVALID_EVENT_TYPE` | 409 | event_type_code not in SCAN_EVENT_TYPES |
| `OUTSIDE_GEOFENCE` | 422 | GPS outside zone boundary |
| `MISSING_PARAMETER` | 400 | Required field absent |
| `SERVER_ERROR` | 500 | Unexpected server failure |

---

## Event Type Reference

### Moving Capacity Events

| Code | Custody After | Materializes | Payment Trigger |
|---|---|---|---|
| `PickedUpAtOrigin` | Driver | Yes (if first) | No |
| `DroppedOffAtOriginGateway` | Gateway Operator | Yes (if first) | No |
| `ArrivedAtOriginGateway` | Gateway Operator | Yes (if first) | No |
| `DispatchedFromOriginGateway` | Driver | Yes (if first) | No |
| `ArrivedAtDestinationGateway` | Gateway Operator | Yes (if first) | No |
| `StagedForPickup` | Gateway Operator | Yes (if first) | No |
| `PickedUpByConsignee` | Consignee | Yes (if first) | ✅ Yes |
| `Exception` | Unchanged | Yes (if first) | Holds unit |

### Stationary Capacity Events

| Code | Custody After | Materializes | Payment Trigger |
|---|---|---|---|
| `FacilityCheckIn` | Warehouse | Yes | No |
| `Staged` | Warehouse | No | No |
| `Exception` | Unchanged | No | Holds unit |
| `FacilityCheckOut` | Released | No | ✅ Yes |

---

## Design Decisions & Tradeoffs

### Why is eligibility computed, not stored?

Storing `eligible: true/false` on `HANDLING_UNIT_GROUPS` creates two sources of truth. If a scan event is added retroactively (dispute resolution, late sync from an offline device), the stored flag becomes stale. Computing from the event log means eligibility is always consistent with the actual record — no reconciliation job needed.

Tradeoff: slightly more expensive to compute. Mitigated by indexing on `handling_unit_id` in `SCAN_EVENTS`.

### Why is address hidden until transaction confirmed?

Supplier confidentiality is a core marketplace trust requirement. Suppliers will not list capacity if buyers can extract location data without completing a transaction. The blind board design — zone name visible, address hidden — was the minimum viable trust model for supplier participation.

Tradeoff: reduces search precision for buyers. Mitigated by ZIP-level search which is precise enough for logistics planning.

### Why is geofence validation a hard fail (not a warning)?

A warning model — "you're outside the zone, are you sure?" — transfers trust enforcement to the UI layer. Any bad actor with API access can bypass the warning. A hard fail at the API layer means scan events are guaranteed to represent verified physical presence, regardless of which client submits them.

Tradeoff: legitimate edge cases (geofence radius too tight, GPS drift in urban canyons) generate false rejections. Mitigated by configurable `geofence_radius_m` per zone — operators can widen the radius for urban facilities.

### Why is `ScanEventType` a reference table, not a database enum?

Adding a new event type to a database enum requires a schema migration — downtime, deployment risk, coordination with engineering. A reference table requires only a new row insert — zero downtime, deployable by an operator. When `CustomsClearance` or `ColdChainBreached` is needed in v2, it's one SQL insert.

---

*This contract is a reference implementation demonstrating PM-level API design thinking applied to a logistics capacity marketplace. Field names, status enums, and business rules reflect a real domain model. No proprietary data or company-specific information is included.*
