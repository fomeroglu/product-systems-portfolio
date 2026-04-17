# Telemetry analysis — container behavioral patterns

**Objective:** Understand how containers actually move through the network using tracker ping data  
**Method:** Analysis of ping data across field-deployed containers  
**Tools:** Python (MovingPandas), ping data from tracker platform

---

## Why telemetry analysis mattered

Deploying trackers on containers generates raw ping data — timestamps, coordinates, battery levels, location accuracy. Raw pings alone don't tell you what a container is doing. The analysis work was about turning raw location events into meaningful behavioral signals:

- Is this container in transit or sitting idle?
- How long has it been at a facility?
- Is it making full cycles or getting stuck somewhere in the network?
- Is the tracker behaving as expected or showing anomalies?

These questions couldn't be answered from raw ping data directly — they required defining what "transit," "stopped," and "cycle" meant in the context of logistics container movement.

---

## Behavioral pattern identification

By comparing time-since-last-ping against distance-moved between consecutive pings, four distinct behavioral patterns emerged from the data:

### Pattern 1 — Stationary, infrequent pings
**What it looks like:** Long time between pings, near-zero distance moved  
**What it means:** Container is not moving. Device is in heartbeat mode — pinging on its standard cycle to confirm it's alive and reporting location.  
**Expected:** Yes. Normal resting state.

### Pattern 2 — Traveling, frequent pings
**What it looks like:** Short time between pings, significant distance moved  
**What it means:** Container is in transit. Motion detection has triggered the device to increase ping frequency.  
**Expected:** Yes. Correct response to movement.

### Pattern 3 — Traveling, delayed pings
**What it looks like:** Significant distance moved, but longer-than-expected time between pings  
**What it means:** Container is moving but reporting is delayed. Most commonly caused by connectivity limitations — GPS signal blocked by metal container structure, or the device was in a low-connectivity zone when motion was detected.  
**Expected:** Partially. Delay is explainable and addressable — switching to WiFi-first location mode reduced the occurrence of this pattern.

### Pattern 4 — Stationary, frequent pings
**What it looks like:** Near-zero distance moved, but short time between pings  
**What it means:** Device is pinging frequently despite not being in transit. Most commonly caused by WiFi reconnection events triggering pings in WiFi-only devices — a significant noise source in comparison vendor data.  
**Expected:** No. Represents unnecessary pings that consume battery and create noise in location data.

---

## Ping frequency analysis

Across the 29-day evaluation period for the selected vendor's pilot containers:

| Ping frequency category | Time between pings | % of all pings |
|---|---|---|
| Hourly | 0–2 hours | 47.3% |
| Frequent | 2–12 hours | 36.6% |
| Heartbeat | 12–24 hours | 16.2% |

This distribution was consistent between travel and no-travel periods — motion detection was correctly triggering more frequent pings during transit without creating excessive noise during stationary periods.

Average ping interval: every 2–7 hours per container across the pilot.

---

## Cycle determination methodology

Understanding container utilization required knowing how many complete cycles each container had made — a cycle being a round trip from origin facility to customer and back.

**The challenge:** Raw ping data shows a series of location points. Determining where one trip ends and another begins requires defining what counts as a "stop" — and a stop in a logistics context is not a single ping but a sustained presence at a location.

**Method: MovingPandas StopSplitter**

The Python library MovingPandas provides trajectory data structures and movement analysis functions. The StopSplitter technique divides a trajectory into segments by identifying stop points based on two parameters: a maximum stop radius and a minimum stop duration.

Parameter selection was validated against both artificial trajectories with known stops and real container trajectories with manually-labeled stops. The selected parameters balanced sensitivity (detecting real stops) against specificity (avoiding false stops from brief pauses).

**Cycle scenarios handled:**

1. **Direct cycle** — container goes to customer, returns directly to origin
2. **Waypoint cycle** — container passes through an intermediate hub on return
3. **Interrupted cycle** — container makes a partial trip, returns partway, then completes
4. **Half cycles** — container reaches a destination but does not return — counted as incomplete

Methodology was applied across the deployed container fleet to generate cycle count data at scale.

---

## Key analytical findings

**Ping reliability:** The selected vendor achieved 100% daily reporting across all pilot containers for the full evaluation period — every container checked in at least once every day.

**Battery-performance correlation:** Analysis of per-device power consumption data revealed that GPS scanning time was the primary driver of battery drain — specifically, failed GPS scans consume significantly more power than successful WiFi fixes. This finding directly informed the WiFi-first configuration recommendation.

**Location anomalies:** One container showed a spurious ping in an unexpected geographic location during transit. Root cause was a cellular location API returning incorrect data when GPS was unavailable. Vendor confirmed this was a rare occurrence and committed to adding a post-processing filter on cellular location data.

**Dwell time patterns:** Dwell time data showed meaningful variation between facilities — some containers were turning quickly while others were sitting for extended periods. This became a direct input into operational conversations about container return velocity.

---

## From telemetry to product decisions

The analysis directly shaped three product decisions:

1. **Default tracker configuration** — WiFi-first mode became the default after GPS blocking patterns were identified in the data, improving both location reliability and battery performance.

2. **Physical design changes** — Tracker placement guidelines for production batches were informed by signal blocking patterns identified in the telemetry.

3. **Cycle count reporting** — The stop detection methodology and validated parameters became the foundation for the container utilization reporting feature — giving customers visibility into how many cycles their containers had completed and where they were spending the most time.

---

*Analysis conducted on live field data from deployed containers. Facility names, carrier partners, and device identifiers have been genericized.*
