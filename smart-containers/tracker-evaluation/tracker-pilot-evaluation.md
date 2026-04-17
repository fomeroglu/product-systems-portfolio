# Tracker pilot evaluation

**Objective:** Select a tracking solution for deployment across a reusable container fleet  
**Vendors evaluated:** Vendor A · Vendor B · Vendor C  
**Pilot scope:** 4 units per vendor, installed on containers sent to real customers in comparable routes and regions  
**Evaluation period:** ~29 days of live field data

---

## Setup

To enable a meaningful side-by-side comparison, containers were configured with one tracker from each vendor installed simultaneously. Routes and regions were kept as similar as possible to control for environmental variables. This was not a lab test — containers operated in live customer environments under real handling and transit conditions.

**Why 4 units per vendor:** Enough to identify consistent behavioral patterns across different handling scenarios without over-committing to vendor pilot programs before a decision was made. Sample size was sufficient to distinguish signal from noise in the telemetry data.

---

## Evaluation dimensions

| Dimension | What we measured |
|---|---|
| Tracking technology | Location methods used, configurability, motion detection capability |
| Tracking performance | Ping reliability, behavioral pattern accuracy, data consistency |
| Battery performance | Power consumption under real conditions, expected device lifetime |
| User interface | Dashboard clarity, data accessibility |
| API integration | Webhook support, payload schema, integration overhead |
| Price | Per-unit cost, subscription model, total cost of ownership |
| Overall reliability | Consistency across the full evaluation period |

---

## Vendor overview

| | Vendor A | Vendor B | Vendor C |
|---|---|---|---|
| Technology | BLE + WiFi + GPS + Cellular | BLE + WiFi + GPS + Cellular | WiFi only |
| Motion detection | Yes — configurable sensitivity | Yes | No |
| Webhook support | Yes (HTTP POST) | No — polling only | No |
| Selected | ✓ | | |

---

## Tracking technology

All three vendors used combinations of BLE, WiFi triangulation, and GPS. The critical differences were in configurability and how each handled connectivity gaps in logistics environments — loading docks, trailers, metal containers, areas with limited WiFi coverage.

**Vendor A** offered configurable location service priority ordering (GPS vs WiFi first), configurable heartbeat timing, and motion-triggered ping frequency increases. Default settings: 24-hour heartbeat with motion-triggered pings every 1 hour when movement detected.

**Vendor B** offered similar core technology but with less configurability on ping behavior and no webhook support.

**Vendor C** used WiFi only — devices pinged every time they connected to an open WiFi network, regardless of time elapsed and with no motion detection. This created unpredictable ping behavior in environments with variable WiFi coverage.

**Key finding:** Vendor C was effectively eliminated early. WiFi-only tracking in a logistics environment — where containers spend significant time in trailers, facilities, and loading docks with inconsistent WiFi — produced unreliable location data.

---

## Tracking performance

Behavioral patterns were identified through analysis of ping data collected during the field pilot. Four distinct patterns emerged when comparing time-since-last-ping against distance moved between pings:

**Pattern 1 — Stationary with infrequent pings**
Normal heartbeat behavior when the container is not moving. Vendor A showed this reliably — containers pinged on the 24-hour heartbeat cycle when stationary.

**Pattern 2 — Traveling with frequent pings**
Device correctly detects motion and increases ping frequency. Vendor A performed reliably — motion detection triggered consistently, producing hourly pings during transit.

**Pattern 3 — Traveling with delayed pings**
Device is moving but reporting is delayed. Observed across all vendors to varying degrees. For Vendor A, delay was typically explained by GPS scan failures when tracker placement was suboptimal — addressed by switching to WiFi-first mode.

**Pattern 4 — Stationary with frequent pings**
Device pinging frequently despite not being in transit. Most common in Vendor C — WiFi reconnection events triggered pings regardless of movement or time elapsed, creating noise in location data.

**Vendor A reliability data (29-day pilot):**
- 100% daily ping reliability — all 4 containers pinged at least once per day for all 29 days
- Ping frequency breakdown: 47.3% hourly (0–2 hrs), 36.6% frequent (2–12 hrs), 16.2% heartbeat (12–24 hrs)
- Average ping interval: every 2–7 hours per container

**Winner: Vendor A**

---

## Battery performance

Battery performance was analyzed using per-device power consumption data across a two-month analysis period.

**Key findings:**

Two of four devices showed statistically expected battery lifetimes of 4+ years. The other two showed worst-case estimates of ~1.5 years — fully explained by GPS-first location ordering. GPS scanning consumes significantly more power than WiFi scanning when GPS lock cannot be achieved inside metal containers. Switching to WiFi-first ordering was projected to extend battery life to 3+ years for these devices.

**Power consumption tradeoffs identified:**
- Increasing motion detection sensitivity 4x adds only 10–15% to average power consumption
- Switching to a 2-hour heartbeat increases power consumption ~400% in rest state due to cellular modem activation
- Primary battery drain sources: failed GPS scans and sensor messages for an unused feature — both addressable through configuration

**Battery consumption during transit (representative):**
- Coast-to-coast trip (~2 days): ~390 mAh consumed
- Regional trip (~1.5 days): ~87 mAh consumed

**Tracker placement finding:**
GPS signal was consistently blocked by the metal container structure in certain mounting positions. No GPS location fixes were recorded during transit for several units. This led to two action items: (1) WiFi-first mode as default configuration, and (2) placement guidelines for future production batches.

---

## API integration

This was a decisive differentiator. The tracker needed to integrate into the platform — not just provide a standalone dashboard.

**Vendor A:**
- Initially offered polling-based REST API (rate limited at 60 requests/hour)
- Webhook support confirmed feasible upon request
- Webhook delivered as standard HTTP POST to a platform-provided endpoint
- Payload schema: device ID, cloud timestamp, capture timestamp, temperature, battery %, latitude, longitude, location type, location ID, dwell time, location accuracy
- Timestamp format inconsistency between webhook and API identified during integration review and resolved by vendor

**Vendor B:**
- REST API with OAuth 2 and MQTT support
- No webhook equivalent — required polling or persistent MQTT connection
- Higher integration engineering overhead for real-time use cases

**Vendor C:**
- No webhook support
- WiFi-triggered pings created unpredictable event frequency — would require significant filtering logic on the receiving end

**Why webhook mattered:**
Polling requires the platform to make timed API calls and manage state between pulls. Push-based webhooks mean the vendor's system delivers data to the platform endpoint on every event — no polling overhead, no rate limit concerns, real-time data delivery. For a container tracking platform, this means location updates reach customers as events happen rather than on a scheduled pull cycle.

**Winner: Vendor A**

---

## Price

Vendor A offered the most competitive total cost of ownership when tracking performance and integration costs were factored in. Vendor C's lower unit cost did not offset the integration overhead and reliability issues.

**Winner: Vendor A**

---

## Decision

**Selected: Vendor A** — won on the three dimensions that mattered most: tracking performance, API integration, and price.

Vendor B was viable on technology but fell short on API integration maturity. Vendor C was eliminated due to WiFi-only tracking and unreliable ping behavior.

---

## Implications for physical container design

The tracker pilot directly informed physical container design decisions:

- **Tracker placement** — GPS signal was blocked by metal container structure in certain positions. Led to WiFi-first configuration as default and placement guidelines for production batches.
- **Orientation sensitivity** — tracker orientation relative to the container wall affected cellular antenna performance. Incorrect installation in early units impacted battery estimates — fed into installation documentation for future deployments.
- **Battery access** — tracker battery replacement access factored into container physical design to avoid requiring full disassembly.

---

*Vendor names have been genericized. Evaluation conducted using live field data from real customer deployments. No proprietary vendor pricing or device-identifying information is included.*
