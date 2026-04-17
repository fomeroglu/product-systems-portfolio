# Tracker webhook integration

**Context:** After selecting a tracking vendor based on pilot evaluation, the integration work began. This document covers the integration decisions made, the issues identified, and how they were resolved.

---

## The integration requirement

The platform needed to receive tracker location and telemetry events in real time. The vendor's default offering was a polling-based REST API — the platform would call the API on a timed interval to pull new data.

**Why polling was not acceptable:**

- Rate limited — insufficient for a growing fleet at scale
- Requires the platform to manage state between pulls
- Introduces latency between when an event occurs and when the platform sees it
- Creates unnecessary infrastructure overhead for a timed job that runs even when no events have occurred

**The requirement stated to the vendor:**
Push-based webhook integration using standard HTTP POST requests, delivered to a platform-provided endpoint upon occurrence of specific events. This is industry-standard practice — the vendor's system initiates delivery to the platform rather than the platform polling for data.

---

## The first webhook delivery — wrong pattern

When the vendor delivered initial webhook documentation, the implementation used WebSocket rather than standard HTTP POST. WebSocket requires:

- A persistent TCP connection maintained 24/7
- Dedicated compute resources to keep the connection alive
- Complex reconnection logic for handling disconnects and transient errors
- Higher infrastructure cost and operational overhead

This was flagged immediately. The concern was not that WebSocket doesn't work — it does — but that it introduces infrastructure complexity that a push-based HTTP POST approach eliminates entirely.

**The ask to the vendor:**
Revert to conventional webhook pattern using HTTP POST requests sent from the vendor's system to a platform-provided endpoint upon specific events. This approach eliminates the need for a continuously active client connection and simplifies event notification management.

**The vendor's response:**
Acknowledged the confusion, confirmed the standard HTTP POST approach was straightforward and aligned with best practices, and committed to delivering it within the week. Turnaround was fast.

---

## The payload

Once the correct webhook pattern was in place, the vendor provided the event payload schema. Each event included:

- **Device identifier** — unique ID for the specific tracker unit
- **Dual timestamps** — one for when the event was captured on the device, one for when it was received in the cloud. The gap between these two values provides a transmission latency signal useful for detecting connectivity issues.
- **Coordinates** — latitude and longitude of the location fix
- **Battery percentage** — remaining battery on the device
- **Location accuracy** — accuracy of the location fix in meters
- **Dwell time** — how long the device had been at the current location
- **Location type** — classification of the location fix method used

The dual timestamp design was particularly useful — it meant the platform could distinguish between an event that happened recently and was delayed in transmission versus an event that genuinely just occurred.

---

## The timestamp format issue

After the webhook went live and data started flowing, an inconsistency was identified between the webhook payload and the REST API — the two systems used different timestamp formats. This mattered because if the webhook went down and a backfill was needed using the REST API, the system would incorrectly identify existing records as new duplicates due to the format mismatch.

Two options were considered:
1. Adjust the backfill logic to compensate for the format difference
2. Ask the vendor to align the webhook format with the API format

Option 2 was preferred — data consistency at the source is cleaner than compensating logic downstream. The vendor updated the webhook payload format within days of the request.

---

## Key decisions and why they matter

**Why push over pull:**
A polling integration is fragile at scale. You're introducing a dependency on timing, state management, and rate limits. A push-based webhook means the vendor's system is responsible for delivery — the platform just needs to be ready to receive. This also simplifies future scaling: adding more containers doesn't increase polling frequency requirements.

**Why HTTP POST over WebSocket:**
WebSocket is appropriate for truly bidirectional, persistent communication. For event notification — where the vendor has new data and needs to tell the platform about it — HTTP POST is the right tool. It's stateless, reliable, and widely supported. Maintaining a persistent WebSocket connection for a one-way event stream is over-engineering.

**Why catch the timestamp mismatch early:**
Timestamp format inconsistencies are the kind of issue that surfaces as a silent data quality problem weeks or months after go-live. A backfill run creates duplicate records, deduplication logic gets added, and the root cause becomes obscured. Catching it during integration testing and fixing it at the source prevents a class of data integrity bugs from ever existing.

---

*All identifying information has been genericized. Integration was conducted with a real IoT tracking vendor as part of a production deployment.*
