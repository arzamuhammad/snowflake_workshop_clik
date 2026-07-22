/* ============================================================================
   08 - AI BI Dashboard : Datamart Baseline
   ----------------------------------------------------------------------------
   Menyiapkan datamart sebagai baseline untuk Dashboards in Snowflake Cowork
   (Dashboards 2.0 / Artifacts 2.0). Tanpa Dynamic Tables:
     - MART_APPLICATIONS   : VIEW fact ter-enrich (grain = 1 aplikasi)
     - MART_APP_MONTHLY    : TABLE pre-agregat (untuk tile ringkas & filter cepat)

   Sumber: LOAN_APPLICATIONS + DIM_* + SCORE_RESULTS + SUBJECT_FEATURES.
   Jalankan di worksheet CLIK_WORKSHOP2.PUBLIC (warehouse GEN2_SMALL).
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;
USE WAREHOUSE GEN2_SMALL;

-- 1) FACT ter-enrich (grain = aplikasi). Dipakai mayoritas tile.
CREATE OR REPLACE VIEW MART_APPLICATIONS AS
SELECT
    a.APPLICATION_ID,
    a.SUBJECT_ID,
    a.APP_DATE,
    DATE_TRUNC('month', a.APP_DATE)  AS APP_MONTH,
    DATE_TRUNC('week',  a.APP_DATE)  AS APP_WEEK,
    YEAR(a.APP_DATE)                 AS APP_YEAR,
    a.CHANNEL,
    a.REQUESTED_AMOUNT,
    a.TENOR_MONTHS,
    a.DECISION,
    IFF(a.DECISION = 'APPROVE', 1, 0) AS IS_APPROVED,
    r.REGION_CODE, r.REGION_NAME, r.ISLAND_GROUP,
    p.PRODUCT_CODE, p.PRODUCT_NAME, p.PRODUCT_CLASS,
    l.LENDER_CODE, l.LENDER_NAME, l.LENDER_TYPE,
    s.PD_PROBABILITY,
    s.CREDIT_SCORE,
    CASE WHEN s.CREDIT_SCORE < 580 THEN '1_Poor'
         WHEN s.CREDIT_SCORE < 670 THEN '2_Fair'
         WHEN s.CREDIT_SCORE < 740 THEN '3_Good'
         WHEN s.CREDIT_SCORE < 800 THEN '4_VeryGood'
         ELSE '5_Excellent' END       AS SCORE_BAND,
    CASE WHEN s.PD_PROBABILITY < 0.10 THEN 'Low'
         WHEN s.PD_PROBABILITY < 0.30 THEN 'Medium'
         ELSE 'High' END              AS RISK_SEGMENT,
    f.DEFAULT_FLAG,
    f.MONTHLY_INCOME,
    f.AGE,
    f.CREDIT_UTILIZATION
FROM LOAN_APPLICATIONS a
LEFT JOIN DIM_REGION      r ON r.REGION_CODE  = a.REGION_CODE
LEFT JOIN DIM_PRODUCT     p ON p.PRODUCT_CODE = a.PRODUCT_CODE
LEFT JOIN DIM_LENDER      l ON l.LENDER_CODE  = a.LENDER_CODE
LEFT JOIN SCORE_RESULTS   s ON s.SUBJECT_ID   = a.SUBJECT_ID
LEFT JOIN SUBJECT_FEATURES f ON f.SUBJECT_ID  = a.SUBJECT_ID;

-- 2) Pre-agregat bulanan (untuk tile ringkas & dropdown filter yang cepat).
--    Re-run tabel ini bila data aplikasi berubah (atau jadwalkan via TASK).
CREATE OR REPLACE TABLE MART_APP_MONTHLY AS
SELECT
    APP_MONTH, APP_YEAR, REGION_NAME, ISLAND_GROUP, PRODUCT_NAME, PRODUCT_CLASS,
    LENDER_TYPE, CHANNEL, DECISION, RISK_SEGMENT, SCORE_BAND,
    COUNT(*)              AS N_APPLICATIONS,
    SUM(IS_APPROVED)      AS N_APPROVED,
    SUM(REQUESTED_AMOUNT) AS TOTAL_REQUESTED,
    AVG(REQUESTED_AMOUNT) AS AVG_REQUESTED,
    AVG(PD_PROBABILITY)   AS AVG_PD,
    AVG(CREDIT_SCORE)     AS AVG_CREDIT_SCORE,
    AVG(DEFAULT_FLAG)     AS DEFAULT_RATE
FROM MART_APPLICATIONS
GROUP BY ALL;

-- 3) Validasi
SELECT 'MART_APPLICATIONS' obj, COUNT(*) rows FROM MART_APPLICATIONS
UNION ALL
SELECT 'MART_APP_MONTHLY',  COUNT(*)      FROM MART_APP_MONTHLY;

/* Catatan:
   - Filter dashboard dievaluasi caller's rights. Untuk domain filter besar,
     pre-agregat (spt MART_APP_MONTHLY) atau tabel distinct membantu kecepatan.
   - Dimensi (REGION/PRODUCT/LENDER) kecil -> filter source 'column' sudah cepat.
   ============================================================================ */
