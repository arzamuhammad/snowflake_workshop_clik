/* ============================================================================
   08 - AI BI Dashboard : Tile Queries (Dashboards 2.0 / Cowork)
   ----------------------------------------------------------------------------
   Kumpulan SQL untuk SETIAP tile dashboard, lengkap dengan placeholder filter
   {{ filter('name') }}. Placeholder ini VALID di dalam tile .dash (bukan di
   worksheet biasa). Untuk uji manual di worksheet, hapus baris WHERE {{...}}.

   Filter yang dipakai (definisikan di panel Filters dashboard):
     date_range     -> kolom APP_DATE      (timestamp, date range / relative)
     island_group   -> kolom ISLAND_GROUP  (string, multi-select, source=column)
     product_class  -> kolom PRODUCT_CLASS (string, multi-select, source=column)
     channel        -> kolom CHANNEL        (string, multi-select, source=column)
     risk_segment   -> kolom RISK_SEGMENT   (string, multi-select, source=static: Low,Medium,High)

   Pola WHERE standar (tempel di tiap tile yang perlu difilter):
     WHERE {{ filter('date_range') }}
       AND {{ filter('island_group') }}
       AND {{ filter('product_class') }}
       AND {{ filter('channel') }}
       AND {{ filter('risk_segment') }}
   ============================================================================ */

-- =========================================================================
-- ROW 1 — SCORECARDS (chart type: Scorecard / KPI)
-- =========================================================================

-- 1a) Total Applications
SELECT COUNT(*) AS total_applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }};

-- 1b) Approval Rate (%)  [scorecard dengan delta jika ditambah periode]
SELECT ROUND(100.0 * AVG(IS_APPROVED), 1) AS approval_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }};

-- 1c) Avg Credit Score
SELECT ROUND(AVG(CREDIT_SCORE)) AS avg_credit_score
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }};

-- 1d) Portfolio Default Rate (%)
SELECT ROUND(100.0 * AVG(DEFAULT_FLAG), 2) AS default_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }};

-- =========================================================================
-- ROW 2 — TIME SERIES
-- =========================================================================

-- 2a) LINE — Monthly application volume
SELECT APP_MONTH, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1 ORDER BY 1;

-- 2b) AREA (stacked) — Monthly volume by DECISION
SELECT APP_MONTH, DECISION, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;
-- (Encoding: X=APP_MONTH, Y=applications, color=DECISION, stack=zero.
--  Untuk AREA NORMALIZED (100%): set stack=normalize di editor.)

-- 2c) LINE + REFERENCE LINE — Approval rate trend vs target (minta CoCo tambah rule line di 85)
SELECT APP_MONTH, ROUND(100.0 * AVG(IS_APPROVED), 1) AS approval_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1 ORDER BY 1;

-- =========================================================================
-- ROW 3 — CATEGORY COMPARISON (BAR)
-- =========================================================================

-- 3a) BAR (vertical) — Applications by Island Group
SELECT ISLAND_GROUP, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1 ORDER BY 2 DESC;

-- 3b) BAR (horizontal) — Top 10 Regions by volume
SELECT REGION_NAME, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
-- (Editor: swap axes / pilih horizontal bar.)

-- 3c) BAR (stacked) — Product Class x Decision
SELECT PRODUCT_CLASS, DECISION, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;

-- 3d) BAR (normalized 100%) — Decision mix by Channel
SELECT CHANNEL, DECISION, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;
-- (Editor: stack = normalize.)

-- =========================================================================
-- ROW 4 — PART TO WHOLE (PIE / DONUT)
-- =========================================================================

-- 4a) DONUT — Application share by Channel
SELECT CHANNEL, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1 ORDER BY 2 DESC;

-- 4b) PIE — Portfolio mix by Risk Segment
SELECT RISK_SEGMENT, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1;

-- =========================================================================
-- ROW 5 — HEATMAP
-- =========================================================================

-- 5a) HEATMAP — Default rate (%) : Island Group x Product Class
SELECT ISLAND_GROUP, PRODUCT_CLASS, ROUND(100.0 * AVG(DEFAULT_FLAG), 2) AS default_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;
-- (Encoding: X=PRODUCT_CLASS, Y=ISLAND_GROUP, color=default_rate_pct.)

-- 5b) HEATMAP — Volume : Score Band x Channel
SELECT SCORE_BAND, CHANNEL, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;

-- =========================================================================
-- ROW 6 — TABLE
-- =========================================================================

-- 6a) TABLE — Lender performance
SELECT LENDER_NAME, LENDER_TYPE,
       COUNT(*)                          AS applications,
       ROUND(100.0 * AVG(IS_APPROVED),1) AS approval_rate_pct,
       ROUND(AVG(PD_PROBABILITY),4)      AS avg_pd,
       ROUND(AVG(CREDIT_SCORE))          AS avg_score,
       ROUND(100.0 * AVG(DEFAULT_FLAG),2) AS default_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY applications DESC;

-- =========================================================================
-- ROW 7 — ADVANCED (via CoCo -> Vega-Lite): scatter / bubble / trellis / waterfall
-- =========================================================================

-- 7a) SCATTER / BUBBLE — Risk vs Approval per Region (bubble size = volume)
--     Prompt CoCo: "make this a bubble chart: X=avg_pd, Y=approval_rate_pct,
--     size=applications, color=ISLAND_GROUP"
SELECT REGION_NAME, ISLAND_GROUP,
       COUNT(*)                           AS applications,
       ROUND(AVG(PD_PROBABILITY),4)       AS avg_pd,
       ROUND(100.0 * AVG(IS_APPROVED),1)  AS approval_rate_pct
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2;

-- 7b) TRELLIS (faceted line) — Monthly volume faceted by Island Group
--     Prompt CoCo: "facet this line chart into small multiples by ISLAND_GROUP"
SELECT APP_MONTH, ISLAND_GROUP, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1,2 ORDER BY 1,2;

-- 7c) WATERFALL / FUNNEL — Decision funnel
--     Prompt CoCo: "render as a horizontal funnel/waterfall from stage order"
SELECT DECISION AS stage, COUNT(*) AS applications
FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS
WHERE {{ filter('date_range') }} AND {{ filter('island_group') }}
  AND {{ filter('product_class') }} AND {{ filter('channel') }} AND {{ filter('risk_segment') }}
GROUP BY 1;

-- =========================================================================
-- MARKDOWN TILE (bukan SQL) — contoh konten:
--   # CLIK Credit Risk Dashboard
--   Sumber: MART_APPLICATIONS · Model: CLIK_PD_MODEL (V2_SNOWPARK_ML)
--   Gunakan filter di atas untuk memfokuskan analisis. Tanya tile apa pun di Cowork.
-- =========================================================================
