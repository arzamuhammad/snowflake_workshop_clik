/* ============================================================================
   04a - Batch Scoring via Model Registry (Warehouse)
   Prerequisite: Model CLIK_PD_MODEL v1 sudah di-register (dari modul 03)
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) Panggil model langsung dari SQL (warehouse inference)
--    Snowflake otomatis memanggil model dari registry.
WITH scored AS (
  SELECT
    SUBJECT_ID,
    CLIK_WORKSHOP2.PUBLIC.CLIK_PD_MODEL!PREDICT_PROBA(*):"output_feature_1"::FLOAT AS pd_score
  FROM SUBJECT_FEATURES
  LIMIT 1000
)
SELECT
  SUBJECT_ID,
  ROUND(pd_score, 4) AS pd_probability,
  300 + ROUND(550 * (1 - pd_score)) AS credit_score,
  CASE
    WHEN pd_score < 0.10 THEN 'APPROVE'
    WHEN pd_score < 0.30 THEN 'REVIEW'
    ELSE 'REJECT'
  END AS decision
FROM scored;

-- 2) Batch scoring penuh: simpan hasil ke tabel SCORE_RESULTS
CREATE OR REPLACE TABLE SCORE_RESULTS AS
SELECT
  SUBJECT_ID,
  CLIK_WORKSHOP2.PUBLIC.CLIK_PD_MODEL!PREDICT_PROBA(*):"output_feature_1"::FLOAT AS pd_probability,
  300 + ROUND(550 * (1 - pd_probability)) AS credit_score,
  CASE
    WHEN pd_probability < 0.10 THEN 'APPROVE'
    WHEN pd_probability < 0.30 THEN 'REVIEW'
    ELSE 'REJECT'
  END AS decision,
  CURRENT_TIMESTAMP() AS scored_at,
  'V1' AS model_version
FROM SUBJECT_FEATURES;

SELECT decision, COUNT(*) AS cnt, ROUND(AVG(pd_probability),4) AS avg_pd
FROM SCORE_RESULTS GROUP BY decision ORDER BY avg_pd;
