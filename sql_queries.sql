-- ============================================================
-- India Infrastructure Cost & Time Overruns — SQL Analysis
-- Database: infra_overruns_v2.db (SQLite)
-- Source: MoSPI Flash Report, January 2025 (1,720 projects, ₹150 Cr+)
-- ============================================================

-- ------------------------------------------------------------
-- QUERY 1: Top 5 sectors by average cost overrun percentage
-- ------------------------------------------------------------
-- Joins projects to sectors (normalized schema) to get readable
-- sector names. AVG() automatically skips NULLs, so project_count
-- is pulled alongside to confirm the average isn't based on an
-- incomplete sample.
SELECT 
    sector_name, 
    AVG(cost_overrun_pct) AS avg_overrun_pct,
    COUNT(*) AS project_count
FROM projects p
JOIN sectors s ON p.sector_id = s.sector_id
GROUP BY sector_name
ORDER BY avg_overrun_pct DESC
LIMIT 5;


-- ------------------------------------------------------------
-- QUERY 2: States with the most "stalled" projects
-- ------------------------------------------------------------
-- "Stalled" defined as: no revised commissioning date logged
-- AND physical progress below 100%. IS NULL is required here —
-- '= NULL' never matches anything in SQL.
SELECT 
    state, 
    COUNT(*) AS stalled_projects
FROM projects
WHERE commission_revised IS NULL
  AND physical_progress_pct < 100
GROUP BY state
ORDER BY stalled_projects DESC
LIMIT 10;


-- ------------------------------------------------------------
-- QUERY 3: Approval-to-commissioning gap (in months)
-- ------------------------------------------------------------
-- Dates are stored as text (MM/YYYY), not native DATE values —
-- the source PDF never gives a day-level date. Converts each
-- date to "total months since year 0" using SUBSTR/INSTR string
-- parsing, then subtracts. This is the standard workaround when
-- dates are stored as text and no DATEDIFF-style function exists.
SELECT 
    project_name,
    approval_date,
    commission_original,
    cost_overrun_pct,
    (CAST(SUBSTR(commission_original, -4) AS INTEGER) * 12 
     + CAST(SUBSTR(commission_original, 1, INSTR(commission_original,'/')-1) AS INTEGER))
    -
    (CAST(SUBSTR(approval_date, -4) AS INTEGER) * 12 
     + CAST(SUBSTR(approval_date, 1, INSTR(approval_date,'/')-1) AS INTEGER))
    AS approval_to_commission_months
FROM projects
WHERE approval_date IS NOT NULL 
  AND commission_original IS NOT NULL
  AND cost_overrun_pct IS NOT NULL
ORDER BY approval_to_commission_months DESC
LIMIT 20;


-- ------------------------------------------------------------
-- QUERY 4: Bucketed correlation — gap length vs. overrun severity
-- ------------------------------------------------------------
-- SQLite has no built-in CORR() function, so this manually bins
-- projects into gap-length buckets using CASE/WHEN and compares
-- average overrun per bucket. Uncovered a non-linear (U-shaped)
-- pattern: very short AND very long gaps both show elevated
-- overruns, while 2-5 year gaps are the most "on-plan" bucket.
SELECT 
    CASE 
        WHEN gap_months < 24 THEN '< 2 years'
        WHEN gap_months < 60 THEN '2-5 years'
        WHEN gap_months < 120 THEN '5-10 years'
        ELSE '10+ years'
    END AS gap_bucket,
    COUNT(*) AS n,
    ROUND(AVG(cost_overrun_pct), 2) AS avg_overrun_pct
FROM (
    SELECT 
        cost_overrun_pct,
        (CAST(SUBSTR(commission_original, -4) AS INTEGER) * 12 
         + CAST(SUBSTR(commission_original, 1, INSTR(commission_original,'/')-1) AS INTEGER))
        -
        (CAST(SUBSTR(approval_date, -4) AS INTEGER) * 12 
         + CAST(SUBSTR(approval_date, 1, INSTR(approval_date,'/')-1) AS INTEGER))
        AS gap_months
    FROM projects
    WHERE approval_date IS NOT NULL 
      AND commission_original IS NOT NULL
)
GROUP BY gap_bucket
ORDER BY n DESC;


-- ------------------------------------------------------------
-- BONUS: Sanity-check query used to catch the state extraction bug
-- ------------------------------------------------------------
-- Running this against the FIRST extraction pass showed Ladakh
-- with 911 projects — implausible for a small UT, and the clue
-- that led to finding the page-break/merged-cell extraction bug.
SELECT state, COUNT(*) 
FROM projects 
GROUP BY state 
ORDER BY COUNT(*) DESC;