# Product Systems Portfolio

**Fatih Omeroglu — Product Manager**  
[LinkedIn](https://www.linkedin.com/in/fomeroglu/) · [fbomeroglu.com](https://www.fbomeroglu.com/) · fatihbaha92@gmail.com

---

## About this portfolio

I build products that sit at the intersection of operations, data, and engineering. This portfolio documents four projects — a physical IoT product, a multi-facility operational platform, a 0→1 SaaS build, and an active agentic development experiment.

Each project folder contains the artifacts I produced: API contracts, SQL analysis, field research, system design documents, and integration specs. These are not case study writeups — every artifact here was produced during the actual build, for products that shipped to real customers.

---

## Projects

### [Smart Containers](./smart-containers/)
**Built and validated a physical + digital product from prototype to deployment**

A reusable trackable metal container deployed across a logistics carrier network. Led physical product development across four design iterations, ran a structured 3-vendor tracker evaluation using live field telemetry, owned the webhook integration end to end, and built a cycle determination methodology in Python to turn raw ping data into container utilization insights.

1,000+ units deployed of the final version.

**Artifacts:** Tracker pilot evaluation · Telemetry analysis · Webhook integration story · Container design iteration

---

### [Sortation Platform](./sortation-platform/)
**Used data to find the real bottleneck — 30% throughput improvement across 12+ facilities**

Redesigned sortation workflows at the weight and dim station — the primary bottleneck in the sortation process. Used SQL scan-event analysis to isolate where packages were stalling, shipped two workflow improvements, and validated impact through before/after throughput measurement.

Deployed across 12+ facilities and 400+ operators.

**Artifacts:** Workflow analysis · SQL queries (6 BigQuery queries) · Before/after flow diagrams

---

### [0→1 SaaS Product (TBA)](./saas-platform/)
**Turned an ambiguous vision into a shippable system — 60% faster validation, 3–5 pilots**

Leading zero-to-one product creation from concept to pilot. Defined MVP scope, designed end-to-end system logic and user flows, and produced contract-first API specs before engineering wrote a line of code. Full artifact set will be published when the project is ready for public release.

**Artifacts:** API contracts · OpenAPI spec *(domain model and full artifact set TBA)*

---

### [Agentic Development (TBA)](./warehouse-module/)
**Directing AI agent execution via product charter and milestone scoping — active build**

Exploring a new PM workflow: product charter as goal vector, milestone-scoped agent execution, and PM-layer decision making on tradeoffs the agent can't resolve. Artifacts will be published as the build progresses.

**Artifacts:** *(TBA — active build)*

---

## Technical skills demonstrated in this portfolio

| Skill | Where |
|---|---|
| SQL (Google BigQuery) | Sortation Platform — 6 queries, window functions, before/after validation |
| API contract design | SaaS Platform — OpenAPI spec, webhook design, idempotency patterns |
| IoT integration | Smart Containers — webhook negotiation, payload schema, timestamp handling |
| Python / data analysis | Smart Containers — MovingPandas cycle determination, telemetry analysis |
| Hardware product development | Smart Containers — 4-batch design iteration, field validation |
| Event-driven architecture | SaaS Platform — scan event pipeline, computed eligibility, state machines |

---

## Background

- **Doctor of Engineering** — Human-Computer Interaction & Industrial Engineering, Lamar University
- **5+ peer-reviewed publications** — cognitive performance, HCI, UI/UX effects
- Previously: FedEx Operations Research, Lactalis Project Engineering
