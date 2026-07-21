/* ============================================================================
   04b - Real-Time Inference via SPCS Model Serving
   Sesuai dokumentasi resmi:
   https://docs.snowflake.com/en/developer-guide/snowflake-ml/inference/real-time-inference-rest-api
   ----------------------------------------------------------------------------
   Prasyarat:
   - Model CLIK_PD_MODEL sudah di Model Registry (default version = V2_SNOWPARK_ML)
   - View SUBJECT_FEATURES_ENCODED sudah ada (lihat 04a_batch_scoring.sql)
   - snowflake-ml-python >= 1.25.0 (GA untuk real-time REST API)
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) Compute pool untuk service (CPU cukup untuk sklearn/xgb/lgbm)
CREATE COMPUTE POOL IF NOT EXISTS CLIK_SCORING_POOL
  MIN_NODES = 1
  MAX_NODES = 2
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300;

-- 2) Privilege wajib untuk membuat public endpoint (ingress)
--    "BIND SERVICE ENDPOINT privilege on account to create a public endpoint"
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE ACCOUNTADMIN;

-- 3) Deploy service dilakukan via Python (snowflake-ml-python) -> lihat 04b_deploy_service.py
--    (create_service tidak tersedia sebagai perintah SQL murni)

-- 4) Setelah service READY, ambil PUBLIC ENDPOINT (ingress_url):
SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE;
--    Kolom ingress_url -> format: <unique-id>-<account>.snowflakecomputing.app
--    URL method: https://<ingress_url>/predict-proba   (underscore -> dash)

-- 5) Cek status service
SHOW SERVICES IN SCHEMA CLIK_WORKSHOP2.PUBLIC;
-- DESCRIBE SERVICE CLIK_PD_SERVICE;   -- kolom dns_name (internal endpoint)

-- 6) (Opsional) izinkan role lain memanggil endpoint
-- GRANT SERVICE ROLE CLIK_PD_SERVICE!ALL_ENDPOINTS_USAGE TO ROLE <role>;

-- 7) (Opsional) panggil via SQL service function (internal, tanpa PAT).
--    Gunakan view ter-encode (60 fitur) - BUKAN tabel mentah, karena model
--    dilatih dengan One-Hot Encoding. Output OBJECT -> key PREDICT_PROBA_1 = PD.
-- SELECT
--   SUBJECT_ID,
--   CLIK_PD_SERVICE!PREDICT_PROBA(* EXCLUDE (SUBJECT_ID)):"PREDICT_PROBA_1"::FLOAT AS pd
-- FROM SUBJECT_FEATURES_ENCODED
-- LIMIT 10;
