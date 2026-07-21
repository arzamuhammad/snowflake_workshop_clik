/* ============================================================================
   CLIK Workshop 2 - Step 3: Feature Lookup dari Hybrid Table (Unistore)
   ----------------------------------------------------------------------------
   DEMO (bukan hands-on lab). Menunjukkan pola "Precalculated Feature Table"
   pada arsitektur real-time decision engine:

     UI -> SPCS endpoint -> [POINT LOOKUP by Subject ID ke Hybrid Table]
        -> Model Serving -> tulis Score Log -> response

   Hybrid Table = tipe tabel Snowflake yang dioptimalkan untuk workload
   operasional/OLTP: row store + primary key index + row-level locking,
   sehingga point lookup 1 baris by PK berlatensi rendah (orde milidetik)
   dan mendukung konkurensi tinggi (target 100-200 TPS).

   Jalankan statement per statement di Snowsight Worksheet untuk demo.
   Referensi: https://docs.snowflake.com/en/user-guide/tables-hybrid
   Catatan: Hybrid Tables GA di region AWS & Azure (akun ini: AWS Jakarta).
   ============================================================================ */

USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;
USE WAREHOUSE GEN2_SMALL;

/* ----------------------------------------------------------------------------
   1) Buat Hybrid Table "Precalculated Feature Table"
      - PRIMARY KEY (SUBJECT_ID)  -> WAJIB & enforced di hybrid table
      - Secondary INDEX (REGION_CODE) -> contoh index tambahan utk filter analitik
      Catatan: PK, UNIQUE, FK di-enforce; index dibuat sinkron saat write.
   ---------------------------------------------------------------------------- */
CREATE OR REPLACE HYBRID TABLE SUBJECT_FEATURES_HT (
    SUBJECT_ID VARCHAR NOT NULL,
    AGE NUMBER(38,0),
    GENDER VARCHAR,
    MONTHLY_INCOME FLOAT,
    EMPLOYMENT_TYPE VARCHAR,
    EDUCATION VARCHAR,
    REGION_CODE VARCHAR,
    DEPENDENTS NUMBER(38,0),
    NUM_ACTIVE_LOANS NUMBER(38,0),
    NUM_CREDIT_CARDS NUMBER(38,0),
    NUM_FINTECH_LOANS NUMBER(38,0),
    NUM_BNPL_ACCOUNTS NUMBER(38,0),
    NUM_LENDERS NUMBER(38,0),
    NUM_INQUIRIES_3M NUMBER(38,0),
    NUM_INQUIRIES_12M NUMBER(38,0),
    MAX_DPD_12M NUMBER(38,0),
    MAX_DPD_24M NUMBER(38,0),
    NUM_LATE_PMT_12M NUMBER(38,0),
    OLDEST_ACCT_AGE_MONTHS NUMBER(38,0),
    AVG_ACCT_AGE_MONTHS NUMBER(38,0),
    TOTAL_OUTSTANDING FLOAT,
    TOTAL_CREDIT_LIMIT FLOAT,
    CREDIT_UTILIZATION FLOAT,
    MONTHLY_INSTALLMENT FLOAT,
    KOL_STATUS NUMBER(38,0),
    CC_UTIL FLOAT,
    KTA_UTIL FLOAT,
    KPR_UTIL FLOAT,
    KKB_UTIL FLOAT,
    BNPL_UTIL FLOAT,
    FINTECH_UTIL FLOAT,
    DPD_MAX_3M NUMBER(38,0),
    DPD_MAX_6M NUMBER(38,0),
    DPD_MAX_12M NUMBER(38,0),
    CNT_LATE30_12M NUMBER(38,0),
    CNT_LATE60_12M NUMBER(38,0),
    CNT_LATE90_12M NUMBER(38,0),
    DPD_MAX_24M NUMBER(38,0),
    INQ_TOTAL_3M NUMBER(38,0),
    INQ_TOTAL_6M NUMBER(38,0),
    INQ_TOTAL_12M NUMBER(38,0),
    INQ_TOTAL_24M NUMBER(38,0),
    NEW_ACCT_12M NUMBER(38,0),
    CLOSED_ACCT_12M NUMBER(38,0),
    UTIL_DELTA_6M FLOAT,
    OUTSTANDING_DELTA_6M FLOAT,
    PAYMENT_RATIO_12M FLOAT,
    REVOLVING_RATIO FLOAT,
    SECURED_RATIO FLOAT,
    ONTIME_RATIO_12M FLOAT,
    BUREAU_SCORE_COMP_01 FLOAT,
    BUREAU_SCORE_COMP_02 FLOAT,
    BUREAU_SCORE_COMP_03 FLOAT,
    BUREAU_SCORE_COMP_04 FLOAT,
    BUREAU_SCORE_COMP_05 FLOAT,
    BUREAU_SCORE_COMP_06 FLOAT,
    BUREAU_SCORE_COMP_07 FLOAT,
    BUREAU_SCORE_COMP_08 FLOAT,
    BUREAU_SCORE_COMP_09 FLOAT,
    BUREAU_SCORE_COMP_10 FLOAT,
    BUREAU_ATTR_001 FLOAT,
    CONSTRAINT PK_SUBJECT_FEATURES_HT PRIMARY KEY (SUBJECT_ID),
    INDEX IDX_HT_REGION (REGION_CODE)
);

/* ----------------------------------------------------------------------------
   2) Muat data dari SUBJECT_FEATURES (1,000,000 baris x 60 feature)
      Di produksi: 100 juta Subject ID via pipeline INSERT/MERGE.
   ---------------------------------------------------------------------------- */
INSERT INTO SUBJECT_FEATURES_HT
    (SUBJECT_ID, AGE, GENDER, MONTHLY_INCOME, EMPLOYMENT_TYPE, EDUCATION, REGION_CODE, DEPENDENTS,
     NUM_ACTIVE_LOANS, NUM_CREDIT_CARDS, NUM_FINTECH_LOANS, NUM_BNPL_ACCOUNTS, NUM_LENDERS,
     NUM_INQUIRIES_3M, NUM_INQUIRIES_12M, MAX_DPD_12M, MAX_DPD_24M, NUM_LATE_PMT_12M,
     OLDEST_ACCT_AGE_MONTHS, AVG_ACCT_AGE_MONTHS, TOTAL_OUTSTANDING, TOTAL_CREDIT_LIMIT,
     CREDIT_UTILIZATION, MONTHLY_INSTALLMENT, KOL_STATUS, CC_UTIL, KTA_UTIL, KPR_UTIL, KKB_UTIL,
     BNPL_UTIL, FINTECH_UTIL, DPD_MAX_3M, DPD_MAX_6M, DPD_MAX_12M, CNT_LATE30_12M, CNT_LATE60_12M,
     CNT_LATE90_12M, DPD_MAX_24M, INQ_TOTAL_3M, INQ_TOTAL_6M, INQ_TOTAL_12M, INQ_TOTAL_24M,
     NEW_ACCT_12M, CLOSED_ACCT_12M, UTIL_DELTA_6M, OUTSTANDING_DELTA_6M, PAYMENT_RATIO_12M,
     REVOLVING_RATIO, SECURED_RATIO, ONTIME_RATIO_12M, BUREAU_SCORE_COMP_01, BUREAU_SCORE_COMP_02,
     BUREAU_SCORE_COMP_03, BUREAU_SCORE_COMP_04, BUREAU_SCORE_COMP_05, BUREAU_SCORE_COMP_06,
     BUREAU_SCORE_COMP_07, BUREAU_SCORE_COMP_08, BUREAU_SCORE_COMP_09, BUREAU_SCORE_COMP_10,
     BUREAU_ATTR_001)
SELECT
     SUBJECT_ID, AGE, GENDER, MONTHLY_INCOME, EMPLOYMENT_TYPE, EDUCATION, REGION_CODE, DEPENDENTS,
     NUM_ACTIVE_LOANS, NUM_CREDIT_CARDS, NUM_FINTECH_LOANS, NUM_BNPL_ACCOUNTS, NUM_LENDERS,
     NUM_INQUIRIES_3M, NUM_INQUIRIES_12M, MAX_DPD_12M, MAX_DPD_24M, NUM_LATE_PMT_12M,
     OLDEST_ACCT_AGE_MONTHS, AVG_ACCT_AGE_MONTHS, TOTAL_OUTSTANDING, TOTAL_CREDIT_LIMIT,
     CREDIT_UTILIZATION, MONTHLY_INSTALLMENT, KOL_STATUS, CC_UTIL, KTA_UTIL, KPR_UTIL, KKB_UTIL,
     BNPL_UTIL, FINTECH_UTIL, DPD_MAX_3M, DPD_MAX_6M, DPD_MAX_12M, CNT_LATE30_12M, CNT_LATE60_12M,
     CNT_LATE90_12M, DPD_MAX_24M, INQ_TOTAL_3M, INQ_TOTAL_6M, INQ_TOTAL_12M, INQ_TOTAL_24M,
     NEW_ACCT_12M, CLOSED_ACCT_12M, UTIL_DELTA_6M, OUTSTANDING_DELTA_6M, PAYMENT_RATIO_12M,
     REVOLVING_RATIO, SECURED_RATIO, ONTIME_RATIO_12M, BUREAU_SCORE_COMP_01, BUREAU_SCORE_COMP_02,
     BUREAU_SCORE_COMP_03, BUREAU_SCORE_COMP_04, BUREAU_SCORE_COMP_05, BUREAU_SCORE_COMP_06,
     BUREAU_SCORE_COMP_07, BUREAU_SCORE_COMP_08, BUREAU_SCORE_COMP_09, BUREAU_SCORE_COMP_10,
     BUREAU_ATTR_001
FROM SUBJECT_FEATURES;

/* (Pembanding) Tabel STANDARD dengan 60 feature yang sama */
CREATE OR REPLACE TABLE SUBJECT_FEATURES_STD AS
SELECT SUBJECT_ID, AGE, GENDER, MONTHLY_INCOME, EMPLOYMENT_TYPE, EDUCATION, REGION_CODE, DEPENDENTS,
       NUM_ACTIVE_LOANS, NUM_CREDIT_CARDS, NUM_FINTECH_LOANS, NUM_BNPL_ACCOUNTS, NUM_LENDERS,
       NUM_INQUIRIES_3M, NUM_INQUIRIES_12M, MAX_DPD_12M, MAX_DPD_24M, NUM_LATE_PMT_12M,
       OLDEST_ACCT_AGE_MONTHS, AVG_ACCT_AGE_MONTHS, TOTAL_OUTSTANDING, TOTAL_CREDIT_LIMIT,
       CREDIT_UTILIZATION, MONTHLY_INSTALLMENT, KOL_STATUS, CC_UTIL, KTA_UTIL, KPR_UTIL, KKB_UTIL,
       BNPL_UTIL, FINTECH_UTIL, DPD_MAX_3M, DPD_MAX_6M, DPD_MAX_12M, CNT_LATE30_12M, CNT_LATE60_12M,
       CNT_LATE90_12M, DPD_MAX_24M, INQ_TOTAL_3M, INQ_TOTAL_6M, INQ_TOTAL_12M, INQ_TOTAL_24M,
       NEW_ACCT_12M, CLOSED_ACCT_12M, UTIL_DELTA_6M, OUTSTANDING_DELTA_6M, PAYMENT_RATIO_12M,
       REVOLVING_RATIO, SECURED_RATIO, ONTIME_RATIO_12M, BUREAU_SCORE_COMP_01, BUREAU_SCORE_COMP_02,
       BUREAU_SCORE_COMP_03, BUREAU_SCORE_COMP_04, BUREAU_SCORE_COMP_05, BUREAU_SCORE_COMP_06,
       BUREAU_SCORE_COMP_07, BUREAU_SCORE_COMP_08, BUREAU_SCORE_COMP_09, BUREAU_SCORE_COMP_10,
       BUREAU_ATTR_001
FROM SUBJECT_FEATURES;

/* ----------------------------------------------------------------------------
   3) Inspeksi objek
   ---------------------------------------------------------------------------- */
SHOW HYBRID TABLES LIKE 'SUBJECT_FEATURES_HT';
SHOW INDEXES IN TABLE SUBJECT_FEATURES_HT;
SELECT COUNT(*) AS total_subjects FROM SUBJECT_FEATURES_HT;

/* ----------------------------------------------------------------------------
   4) *** INTI DEMO STEP 3 *** : POINT LOOKUP BY PRIMARY KEY
      Lapisan orkestrasi mengirim Subject ID -> ambil ~60 feature dalam 1 baris.
      Ini pola scoring real-time: fitur diambil untuk dikirim ke model service.
   ---------------------------------------------------------------------------- */
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT *
FROM SUBJECT_FEATURES_HT
WHERE SUBJECT_ID = 'SUBJ000123456';

/* EXPLAIN: hybrid table memakai INDEX/PRIMARY KEY untuk single-row access */
EXPLAIN
SELECT * FROM SUBJECT_FEATURES_HT WHERE SUBJECT_ID = 'SUBJ000123456';

/* Lookup by secondary index (REGION_CODE) */
SELECT COUNT(*) AS n_in_region FROM SUBJECT_FEATURES_HT WHERE REGION_CODE = 'DKI';

/* ----------------------------------------------------------------------------
   5) Perbandingan Hybrid vs Standard — single-row point lookup
      Jalankan masing-masing; lihat Query Profile -> "bytes scanned".
      - Hybrid: bytes_scanned = 0 (index seek, row-store fast-path).
      - Standard: ~80-90 MB scanned (baca micro-partition, walau hanya 1 baris).
   ---------------------------------------------------------------------------- */
-- Hybrid Table
SELECT SUBJECT_ID, AGE, REGION_CODE, MONTHLY_INCOME, CREDIT_UTILIZATION, MAX_DPD_12M
FROM SUBJECT_FEATURES_HT
WHERE SUBJECT_ID = 'SUBJ000777777';

-- Standard Table (query yang sama)
SELECT SUBJECT_ID, AGE, REGION_CODE, MONTHLY_INCOME, CREDIT_UTILIZATION, MAX_DPD_12M
FROM SUBJECT_FEATURES_STD
WHERE SUBJECT_ID = 'SUBJ000777777';

/* ----------------------------------------------------------------------------
   6) Simulasi tulis operasional (OLTP) - hybrid table mendukung
      high-concurrency single-row INSERT/UPDATE/DELETE dengan row-level locking.
   ---------------------------------------------------------------------------- */
UPDATE SUBJECT_FEATURES_HT
SET CREDIT_UTILIZATION = 0.42, NUM_INQUIRIES_3M = NUM_INQUIRIES_3M + 1
WHERE SUBJECT_ID = 'SUBJ000123456';

SELECT SUBJECT_ID, CREDIT_UTILIZATION, NUM_INQUIRIES_3M
FROM SUBJECT_FEATURES_HT
WHERE SUBJECT_ID = 'SUBJ000123456';

/* ----------------------------------------------------------------------------
   7) STANDARD TABLE latency & bytes_scanned (per-query, muncul di QUERY_HISTORY)
      Perhatikan bytes_scanned ~80-90 MB per lookup — scan micro-partition.
   ---------------------------------------------------------------------------- */
SELECT
    LEFT(query_text, 60)       AS query_preview,
    total_elapsed_time         AS elapsed_ms,
    bytes_scanned,
    rows_produced,
    start_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION(RESULT_LIMIT => 50))
WHERE query_text ILIKE 'SELECT%SUBJECT_FEATURES_STD%SUBJECT_ID%'
ORDER BY start_time DESC;

/* ----------------------------------------------------------------------------
   8) HYBRID TABLE engine metrics (AGGREGATE_QUERY_HISTORY)
      Point lookup hybrid dilayani via ROW-STORE FAST-PATH:
      - TIDAK men-scan micro-partition -> bytes_scanned=0 (bukti index seek).
      - Diagregasi di AGGREGATE_QUERY_HISTORY (bukan per-query di QUERY_HISTORY).
      Note: ACCOUNT_USAGE views ada delay populasi ~45 menit.
   ---------------------------------------------------------------------------- */
SELECT
    interval_start_time,
    interval_end_time,
    calls,
    total_elapsed_time,
    execution_time,
    compilation_time,
    bytes_scanned,
    query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.AGGREGATE_QUERY_HISTORY
WHERE query_text ILIKE '%SUBJECT_FEATURES_HT%WHERE SUBJECT_ID%'
  AND interval_start_time >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
ORDER BY interval_start_time DESC
LIMIT 10;

/* ----------------------------------------------------------------------------
   Catatan demo:
   - Untuk BUKTI konkurensi & TPS, jalankan benchmark Python:
     SNOWFLAKE_CONNECTION_NAME=ardiyanmuhammad python 04c_hybrid_table_benchmark.py
   - Hybrid Table: BYTES_SCANNED = 0 karena ambil 1 baris langsung dari PK index /
     row-store. Standard Table: SCAN ~80-90 MB micro-partition setiap lookup.
   - Implikasi pada skala produksi (100M baris): scan standard membesar linier
     sementara hybrid tetap O(1) index seek. Pada 100-200 TPS, scan berulang kali
     membebani warehouse; hybrid menanganinya dengan row-level lock tanpa contention.
   - Opsi native ringkas (PREVIEW): Online Feature Store integration membuat
     model service melakukan lookup fitur ini otomatis.

   -- Cleanup (opsional):
   -- DROP TABLE IF EXISTS SUBJECT_FEATURES_HT;
   -- DROP TABLE IF EXISTS SUBJECT_FEATURES_STD;
   ============================================================================ */
