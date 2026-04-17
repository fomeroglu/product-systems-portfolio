# Smart Containers

**Role:** Product Manager  
**Scope:** Physical + digital product — reusable trackable metal containers deployed across a logistics carrier network  
**Outcome:** 1,000+ units deployed of final version across live customer operations

---

## The problem

Reusable containers moving through a logistics network are invisible. Once a container leaves a facility, there is no reliable way to know where it is, how long it has been there, or whether it is making productive cycles. Carriers were relying on manual counts, driver reports, and spreadsheets to track container locations — methods that break down at scale.

The goal was to build a container that was both physically optimized for logistics operations and digitally connected — giving operators real-time visibility into container location, dwell time, and cycle performance.

---

## What I led

**Physical product development** — defined container specifications, managed design iteration across production batches, analyzed field failure data, and validated each iteration before the next batch shipped.

**Tracker vendor evaluation** — designed and ran a structured 3-vendor pilot evaluation across 29 days of live field data. Identified four behavioral patterns from telemetry data through custom analysis. Selected vendor based on tracking performance, API integration, and price.

**Integration ownership** — drove the webhook requirement with the selected vendor. Identified an incorrect initial implementation, pushed for the correct pattern, caught a timestamp format mismatch between webhook and REST API, and got both resolved before go-live.

**Telemetry analysis** — worked with the data team to define container behavioral patterns from ping data and build a cycle determination methodology using Python and MovingPandas. Analysis directly informed product decisions on tracker configuration and container design.

---

## The product

The container was designed as a modular interface between different package handling systems — sortation equipment, trailers, forklifts, robots, and dock employees — without requiring infrastructure changes at any facility.

Each container was assigned a structured asset ID (`TRC-XXXX`) with a QR code linking to its platform record — tracking location history, cycle counts, and maintenance status.

---

## Design iteration arc

| Stage | Key changes | Trigger |
|---|---|---|
| Controlled field pilot | Initial design deployed to early adopter customers | Deliberate staged approach before full production |
| Design validation | Structural refinements, hardware upgrades, validation protocol established | Pilot learnings |
| Scaled batch | Upgraded frame, improved net design, all refinements built in | Validated design |
| Full redesign | Comprehensive redesign across all components | Two production cycles of field data |

Each stage was validated before the next committed. Starting with a controlled pilot rather than going straight to full production was a deliberate call — the cost of learning early is far lower than discovering design gaps at scale.

---

## Tracker evaluation summary

Three vendors evaluated across 7 dimensions over a 29-day live pilot. 4 units per vendor installed on containers sent to real customers on comparable routes.

| Dimension | Winner |
|---|---|
| Tracking performance | Vendor A — 100% daily ping reliability, consistent behavioral patterns |
| API integration | Vendor A — webhook-first, HTTP POST, clean payload schema |
| Price | Vendor A — best value when integration costs factored in |

The four behavioral patterns were identified through our own analysis of ping frequency vs distance moved — not from vendor documentation. This pattern framework became the foundation for how container movement was monitored post-deployment.

---

## Integration story

The webhook integration required three rounds of correction before it was right:

1. **Wrong pattern** — vendor delivered WebSocket instead of HTTP POST. Identified and pushed for the standard webhook pattern.
2. **Payload delivered** — vendor provided event schema with device ID, dual timestamps, coordinates, battery percentage, dwell time, and location accuracy.
3. **Timestamp mismatch** — webhook and REST API used different timestamp formats, which would have caused duplicate records during backfill scenarios. Caught during integration review, fixed at the source.

Each issue was caught before go-live. The final integration was push-based, real-time, and operationally sound.

---

## Telemetry analysis summary

Four behavioral patterns identified from ping data analysis:

- **Stationary + infrequent pings** — normal heartbeat behavior
- **Traveling + frequent pings** — motion detection working correctly
- **Traveling + delayed pings** — connectivity limitation, addressable via configuration change
- **Stationary + frequent pings** — noise pattern, most common in WiFi-only devices

Cycle determination used Python MovingPandas StopSplitter with parameters validated against both artificial trajectories with known stops and manually-labeled real container trajectories. Applied across the deployed fleet.

---

## Artifacts in this folder

| File | What it is |
|---|---|
| `tracker-evaluation/tracker-pilot-evaluation.md` | 3-vendor structured evaluation — technology, performance, battery, API, price |
| `tracker-evaluation/telemetry-analysis.md` | Behavioral pattern analysis and cycle determination methodology |
| `integration/webhook-integration-story.md` | Full integration arc — requirement, wrong delivery, corrections, go-live |
| `container-design/container-design-iteration.md` | Physical design evolution across four production batches |

---

*All vendor names, carrier partner names, and facility details have been genericized. No proprietary operational data or third-party identifying information is included.*
