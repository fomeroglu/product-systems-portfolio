-- ============================================================
-- Sortation Platform — SQL Analysis
-- Written in Google BigQuery SQL
-- These queries were used to identify workflow bottlenecks,
-- validate process improvements, and measure adoption of
-- changes across facilities.
-- ============================================================


-- ============================================================
-- Q1: Throughput by station and facility
-- Business question: How many packages per hour is each
-- weight & dim station processing? Which facilities are
-- underperforming relative to the network average?
-- Decision: Established baseline before workflow changes.
-- Identified which facilities needed prioritized rollout.
-- ============================================================

SELECT
  facility_id,
  station_id,
  DATE(scan_time) AS scan_date,
  COUNT(DISTINCT tracking_number) AS packages_processed,
  COUNT(DISTINCT operator_id) AS active_operators,
  TIMESTAMP_DIFF(
    MAX(scan_time),
    MIN(scan_time),
    HOUR
  ) AS hours_active,
  ROUND(
    COUNT(DISTINCT tracking_number) /
    NULLIF(TIMESTAMP_DIFF(MAX(scan_time), MIN(scan_time), HOUR), 0),
    1
  ) AS packages_per_hour
FROM scan_events
WHERE
  event_type = 'WEIGHT_DIM'
  AND scan_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY
  facility_id,
  station_id,
  scan_date
ORDER BY
  packages_per_hour ASC;


-- ============================================================
-- Q2: Dwell time between stages — where are packages stalling?
-- Business question: How long does a package spend between
-- each stage of the sortation process? Which stage has the
-- highest dwell time?
-- Decision: Confirmed weight & dim was the primary bottleneck,
-- not containerization or staging as initially assumed.
-- ============================================================

WITH stage_times AS (
  SELECT
    tracking_number,
    facility_id,
    event_type,
    scan_time,
    LAG(scan_time) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_scan_time,
    LAG(event_type) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_event_type
  FROM scan_events
  WHERE scan_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
)

SELECT
  prev_event_type AS from_stage,
  event_type AS to_stage,
  COUNT(*) AS sample_size,
  ROUND(AVG(
    TIMESTAMP_DIFF(scan_time, prev_scan_time, MINUTE)
  ), 1) AS avg_minutes,
  ROUND(APPROX_QUANTILES(
    TIMESTAMP_DIFF(scan_time, prev_scan_time, MINUTE), 100
  )[OFFSET(50)], 1) AS median_minutes,
  ROUND(APPROX_QUANTILES(
    TIMESTAMP_DIFF(scan_time, prev_scan_time, MINUTE), 100
  )[OFFSET(95)], 1) AS p95_minutes
FROM stage_times
WHERE
  prev_scan_time IS NOT NULL
  AND TIMESTAMP_DIFF(scan_time, prev_scan_time, MINUTE) < 120
GROUP BY from_stage, to_stage
ORDER BY avg_minutes DESC;


-- ============================================================
-- Q3: Package type distribution by facility
-- Business question: What percentage of volume at each
-- facility is made up of package types affected by the
-- weight only mode improvement (flats, envelopes, polybags)?
-- Decision: Quantified the business case for weight only mode.
-- Facilities with higher flat/envelope volume had the most
-- to gain from the improvement.
-- ============================================================

SELECT
  facility_id,
  package_type,
  COUNT(DISTINCT tracking_number) AS package_count,
  ROUND(
    COUNT(DISTINCT tracking_number) * 100.0 /
    SUM(COUNT(DISTINCT tracking_number)) OVER (PARTITION BY facility_id),
    1
  ) AS pct_of_facility_volume
FROM scan_events
WHERE
  event_type = 'WEIGHT_DIM'
  AND scan_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY facility_id, package_type
ORDER BY facility_id, pct_of_facility_volume DESC;


-- ============================================================
-- Q4: Scan completion rate by facility
-- Business question: What percentage of packages complete
-- all required scan stages? Which facilities have operators
-- skipping steps?
-- Decision: Identified facilities with low scan completion
-- as candidates for operator training and workflow review.
-- A low completion rate indicated process friction, not
-- just volume issues.
-- ============================================================

WITH expected_stages AS (
  SELECT
    tracking_number,
    facility_id,
    COUNTIF(event_type = 'WEIGHT_DIM') AS has_weight_dim,
    COUNTIF(event_type = 'CONTAINERIZATION') AS has_containerization,
    COUNTIF(event_type = 'STAGING') AS has_staging,
    COUNTIF(event_type = 'DISPATCH') AS has_dispatch
  FROM scan_events
  WHERE scan_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  GROUP BY tracking_number, facility_id
)

SELECT
  facility_id,
  COUNT(DISTINCT tracking_number) AS total_packages,
  COUNTIF(has_weight_dim > 0) AS completed_weight_dim,
  COUNTIF(has_containerization > 0) AS completed_containerization,
  COUNTIF(has_staging > 0) AS completed_staging,
  COUNTIF(has_dispatch > 0) AS completed_dispatch,
  ROUND(
    COUNTIF(has_dispatch > 0) * 100.0 /
    NULLIF(COUNT(DISTINCT tracking_number), 0),
    1
  ) AS end_to_end_completion_pct
FROM expected_stages
GROUP BY facility_id
ORDER BY end_to_end_completion_pct ASC;


-- ============================================================
-- Q5: Workflow adoption — pre vs post release comparison
-- Business question: After shipping the activity area
-- pre-selection improvement, did operators actually adopt
-- the new flow? Did throughput improve at pilot facilities
-- before we rolled out globally?
-- Decision: Used to validate each release in pilot facilities
-- before broader rollout. If adoption was low or throughput
-- unchanged, we investigated before expanding.
-- ============================================================

WITH pre_release AS (
  SELECT
    facility_id,
    station_id,
    COUNT(DISTINCT tracking_number) AS packages_processed,
    COUNT(DISTINCT DATE(scan_time)) AS days_active,
    ROUND(
      COUNT(DISTINCT tracking_number) /
      NULLIF(COUNT(DISTINCT DATE(scan_time)), 0),
      0
    ) AS avg_daily_packages
  FROM scan_events
  WHERE
    event_type = 'WEIGHT_DIM'
    AND scan_time BETWEEN '2024-01-01' AND '2024-02-01'
  GROUP BY facility_id, station_id
),

post_release AS (
  SELECT
    facility_id,
    station_id,
    COUNT(DISTINCT tracking_number) AS packages_processed,
    COUNT(DISTINCT DATE(scan_time)) AS days_active,
    ROUND(
      COUNT(DISTINCT tracking_number) /
      NULLIF(COUNT(DISTINCT DATE(scan_time)), 0),
      0
    ) AS avg_daily_packages
  FROM scan_events
  WHERE
    event_type = 'WEIGHT_DIM'
    AND scan_time BETWEEN '2024-02-01' AND '2024-03-01'
  GROUP BY facility_id, station_id
)

SELECT
  pre.facility_id,
  pre.station_id,
  pre.avg_daily_packages AS pre_release_daily,
  post.avg_daily_packages AS post_release_daily,
  post.avg_daily_packages - pre.avg_daily_packages AS daily_delta,
  ROUND(
    (post.avg_daily_packages - pre.avg_daily_packages) * 100.0 /
    NULLIF(pre.avg_daily_packages, 0),
    1
  ) AS pct_change,
  CASE
    WHEN post.avg_daily_packages > pre.avg_daily_packages * 1.1 THEN 'Improved'
    WHEN post.avg_daily_packages < pre.avg_daily_packages * 0.9 THEN 'Declined'
    ELSE 'Stable'
  END AS adoption_trend
FROM pre_release pre
LEFT JOIN post_release post
  ON pre.facility_id = post.facility_id
  AND pre.station_id = post.station_id
ORDER BY pct_change DESC;


-- ============================================================
-- Q6: Dwell time before vs after workflow improvement
-- Business question: Did the activity area pre-selection
-- change actually reduce dwell time at the weight & dim
-- stage? How does average processing time per package
-- compare before and after the release?
-- Decision: Primary validation query. Confirmed the workflow
-- change delivered measurable throughput improvement before
-- global rollout was approved.
-- ============================================================

WITH before_change AS (
  SELECT
    facility_id,
    tracking_number,
    event_type,
    scan_time,
    LAG(scan_time) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_scan_time,
    LAG(event_type) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_event_type
  FROM scan_events
  WHERE
    scan_time BETWEEN '2024-01-01' AND '2024-02-01'
),

after_change AS (
  SELECT
    facility_id,
    tracking_number,
    event_type,
    scan_time,
    LAG(scan_time) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_scan_time,
    LAG(event_type) OVER (
      PARTITION BY tracking_number
      ORDER BY scan_time ASC
    ) AS prev_event_type
  FROM scan_events
  WHERE
    scan_time BETWEEN '2024-02-01' AND '2024-03-01'
),

before_summary AS (
  SELECT
    facility_id,
    'before' AS period,
    ROUND(AVG(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND)
    ), 1) AS avg_seconds_per_package,
    ROUND(APPROX_QUANTILES(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND), 100
    )[OFFSET(50)], 1) AS median_seconds,
    ROUND(APPROX_QUANTILES(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND), 100
    )[OFFSET(95)], 1) AS p95_seconds,
    COUNT(*) AS sample_size
  FROM before_change
  WHERE
    prev_event_type = 'WEIGHT_DIM'
    AND event_type = 'WEIGHT_DIM'
    AND prev_scan_time IS NOT NULL
    AND TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND) < 300
  GROUP BY facility_id
),

after_summary AS (
  SELECT
    facility_id,
    'after' AS period,
    ROUND(AVG(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND)
    ), 1) AS avg_seconds_per_package,
    ROUND(APPROX_QUANTILES(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND), 100
    )[OFFSET(50)], 1) AS median_seconds,
    ROUND(APPROX_QUANTILES(
      TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND), 100
    )[OFFSET(95)], 1) AS p95_seconds,
    COUNT(*) AS sample_size
  FROM after_change
  WHERE
    prev_event_type = 'WEIGHT_DIM'
    AND event_type = 'WEIGHT_DIM'
    AND prev_scan_time IS NOT NULL
    AND TIMESTAMP_DIFF(scan_time, prev_scan_time, SECOND) < 300
  GROUP BY facility_id
)

SELECT
  COALESCE(b.facility_id, a.facility_id) AS facility_id,
  b.avg_seconds_per_package AS before_avg_seconds,
  a.avg_seconds_per_package AS after_avg_seconds,
  b.median_seconds AS before_median,
  a.median_seconds AS after_median,
  b.p95_seconds AS before_p95,
  a.p95_seconds AS after_p95,
  ROUND(
    (b.avg_seconds_per_package - a.avg_seconds_per_package) * 100.0 /
    NULLIF(b.avg_seconds_per_package, 0),
    1
  ) AS pct_improvement,
  CASE
    WHEN a.avg_seconds_per_package < b.avg_seconds_per_package * 0.9
      THEN 'Significant improvement'
    WHEN a.avg_seconds_per_package < b.avg_seconds_per_package
      THEN 'Marginal improvement'
    ELSE 'No improvement'
  END AS outcome
FROM before_summary b
FULL OUTER JOIN after_summary a
  ON b.facility_id = a.facility_id
ORDER BY pct_improvement DESC;
