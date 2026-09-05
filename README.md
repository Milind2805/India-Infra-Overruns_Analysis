# India Infrastructure Cost & Time Overruns — Analysis

Analysis of 1,720 Indian central government infrastructure projects
(₹150 Cr+) using data extracted from the Ministry of Statistics and
Programme Implementation's (MoSPI) Flash Report, January 2025.

**[Dashboard]("D:\Infra_Overruns_Analysis\dashboard\infra_overruns_project_powerBI.pbix") | Full .pbix file in `/dashboard`

---

## Pipeline India-Infra-Overruns_Analysis

PDF (MoSPI Flash Report) → Python extraction (pdfplumber) →
Cleaning & parsing (pandas) → SQLite (analysis) → Power BI (dashboard)

The source data exists only as an unstructured PDF — no CSV, no API,
and the newer PAIMANA portal (na-proj.mospi.gov.in) offers no export
option either. This project builds a full pipeline from scratch to
turn a 200+ page government report into structured, analyzable data.

## Key Findings

- **Railways and DPIIT** show the highest average cost overruns among
  major sectors (~95% and ~142% respectively)
- **52.5%** of ongoing projects have no revised commissioning date
  logged despite being behind schedule — delays that haven't even
  been officially acknowledged
- The relationship between **approval-to-commissioning gap and cost
  overrun is non-linear**: both very short gaps (unrealistically
  tight original timelines) and very long gaps (genuinely troubled
  megaprojects) show elevated overruns, while 2-5 year gaps are the
  most "on-plan" bucket
- Road Transport & Highways, despite having the most projects (1,059),
  is comparatively disciplined on cost overrun — contradicting the
  media narrative that road projects are the worst offenders

## Data Quality Challenges

This project surfaced two genuine data-quality bugs worth documenting,
since finding and fixing them mattered more to the final numbers than
the extraction itself.

### Bug 1: Silent state misattribution during PDF extraction

The initial extraction pass showed **Ladakh with 911 projects** —
implausible for a small Union Territory. Investigation traced this to
`pdfplumber`'s `extract_tables()` silently returning `None` for the
state column on the first row of each new state group, specifically
when that row fell right at a page break (a merged-cell rendering
issue). My forward-fill logic then incorrectly carried the previous
state (e.g. Ladakh) forward across dozens of unrelated rows.

**Fix:** cross-validated `extract_tables()` output against
`extract_words()` (raw word positions), recovering the correct state
name by matching word coordinates to each row's vertical band instead
of relying solely on the table-grid cell structure.

**Impact:** Ladakh corrected to 7 projects (its true count). This also
fixed the *sector* column via the same mechanism — Railways went from
an apparent 28 tracked projects to the correct 218, materially changing
the sector overrun rankings.

### Bug 2: DAX vs. SQL disagree on NULL comparisons

Building a "% of stalled projects" measure in Power BI (DAX) returned
62%, while the equivalent SQL query — validated first — gave 52.5%.

**Root cause:** DAX evaluates `BLANK() < 100` as `TRUE`, coercing a
missing `physical_progress_pct` value to `0` in a numeric comparison.
SQL, by contrast, treats `NULL < 100` as unknown (effectively false),
correctly excluding those rows. Same business logic, two different
engines, two different answers — until the DAX measure explicitly
excluded blank progress values with `NOT ISBLANK(...)`.

## Repository Structure

├── data/
│ ├── raw/ # Original MoSPI Flash Report PDF
│ └── processed/ # Cleaned, structured CSV output
├── database/
│ ├── schema.sql # SQLite schema (normalized: projects/sectors/agencies)
│ └── infra_overruns_v2.db # Populated database
├── analysis/
│ └── sql_queries.sql # All analysis queries, commented
└── dashboard/
├── infra_overruns_project_powerBI.pbix
└── dashboard_screenshot.png

## Tech Stack

Python (`pdfplumber`, `pandas`) · SQLite · Power BI · DAX
