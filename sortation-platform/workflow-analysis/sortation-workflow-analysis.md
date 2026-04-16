# Sortation workflow analysis — weight & dim optimization

## The problem

The weight and dim station was the first scan any package received — and the biggest bottleneck in the entire sortation process. Every package had to pass through it before moving to secondary sort. At peak volume, this single station constrained throughput for the entire facility.

Field observations and operator feedback pointed to two distinct friction points. Without data to isolate which one mattered most, any engineering effort risked targeting the wrong layer.

**Baseline throughput: 266 packages per hour** (measured across package types at the weight and dim station).

---

## Discovery

**Field observations** were conducted at facilities selected to represent different operational profiles across the network — different volumes, different package mixes, different operator configurations.

**Operator feedback** was gathered from operations managers across facilities. Key themes:

- Operators described the scanning sequence as repetitive and interruptible
- Problematic package types (flats, envelopes, polybags) caused unpredictable stops
- No visibility into per-station throughput metrics — operators couldn't see their own performance

**Critical finding from the heuristic review:**
> "There are no accurate ways to measure throughput. There are no available metrics to monitor throughput, completion rates, or accurate throughput per station."

This meant the problem was not just the workflow — it was also the absence of observability. Before improving the process, we needed to establish measurement.

---

## Root cause analysis

Two distinct bottlenecks were identified within the weight and dim station:

### Bottleneck 1 — Redundant equipment scan

**Original flow:**
```
Pick up pallet → Scan package → Place on scale → Scan equipment → Dim triggered
```

Every package required two scans — one to identify the package, one to trigger the specific dimensioning unit. With multiple units on site, operators had to re-select their equipment for every single package. There was no session memory.

**The insight:** The equipment selection was a system constraint, not an operational requirement. Operators were not choosing different equipment per package — they were re-confirming the same equipment hundreds of times per session.

### Bottleneck 2 — Manual dimension entry for incompatible package types

Flats, envelopes, and polybags regularly triggered a "No Object Detected" error from the dimensioning equipment. When this happened, the operator had to stop, switch to weight-only mode manually, and hand-key the package dimensions.

**The insight:** For these package types, dimensions were not required downstream. The system was forcing manual entry for data it did not need.

---

## Solutions shipped

### Improvement 1 — Activity area pre-selection

**New flow:**
```
[Once per session] Scan equipment → Select activity area
[Per package] Pick up pallet → Scan package only → Place on scale → Dim triggered
```

Operators scan their equipment once at the start of a session to pre-select their activity area. For the remainder of the session, they scan packages only — no equipment re-scan required.

**Result:** 50% reduction in scans per package at the weight and dim station.

**Technical note:** The equipment vendor confirmed this pattern is supported. A short delay was added post-package-scan to allow the operator to clear the frame before measurement triggers — preventing false reads.

---

### Improvement 2 — Weight only mode

For package types where dimensioning is not required (flats, envelopes, polybags), operators can enable weight only mode. The system pings the API for weight measurement only — no dimension capture, no manual entry.

**Affected package types:**
- Flats — dimensioner could not reliably detect
- Envelopes — same issue; dimensions not required downstream  
- Polybags — irregular shape caused frequent "No Object Detected" errors

**Unaffected package types:**
- Standard and medium boxes — dimensioner reliable, standard flow applies

**Result:** Eliminated the most disruptive interruption within the bottleneck. A single flat or envelope previously stopped the line for ~30 additional seconds of manual entry. At high volume across a full shift, this compounded significantly.

---

## Outcome

| Metric | Before | After |
|---|---|---|
| Scans per package (standard) | 2 | 1 |
| Manual entry for flats/envelopes | Required | Eliminated |
| Throughput improvement | Baseline | 30% increase |
| Deployment | — | 12+ facilities, 400+ operators |

The weight and dim station moved from the primary constraint to a throughput-neutral stage in the overall sortation flow.

---

## Key product decisions

**Why two separate improvements instead of one?**

The two bottlenecks had different root causes and different solutions. Combining them into a single release would have made it impossible to isolate which change drove which outcome. Shipping them in sequence allowed validation of each improvement independently before broader rollout.

**Why weight only mode instead of auto-detection?**

Auto-detection of package type would require additional engineering investment and introduce new failure modes. Weight only mode is operator-initiated — the operator knows the package type better than the system does. This kept the solution simple, reliable, and deployable immediately.

**Why measure throughput at the station level?**

The heuristic review identified that no throughput metrics existed at the station level. Measuring at packages-per-hour per station gave operators visibility into their own performance for the first time — and gave the product team the data needed to validate that changes were working.

---

*This analysis is based on field research, operator feedback, and throughput measurement conducted across sortation facilities. Facility names and operator identifying information are not included.*
