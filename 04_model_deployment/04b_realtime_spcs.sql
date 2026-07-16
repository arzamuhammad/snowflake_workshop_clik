/* ============================================================================
   04b - Real-Time Inference via SPCS (Model Serving)
   Deploy model sebagai REST service di Snowpark Container Services.
   Prerequisite: Model CLIK_PD_MODEL v1 sudah di registry, compute pool ada.
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) Buat compute pool (jika belum ada)
CREATE COMPUTE POOL IF NOT EXISTS CLIK_SCORING_POOL
  MIN_NODES = 1
  MAX_NODES = 2
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 120;

DESCRIBE COMPUTE POOL CLIK_SCORING_POOL;

-- 2) Deploy model sebagai service (native Model Serving - no Dockerfile!)
--    Ini menggunakan snowflake-ml-python di notebook/Python:
--
--    from snowflake.ml.registry import Registry
--    reg = Registry(session=session, database_name='CLIK_WORKSHOP2', schema_name='PUBLIC')
--    mv = reg.get_model('CLIK_PD_MODEL').version('V1')
--    mv.create_service(
--        service_name='CLIK_PD_SERVICE',
--        service_compute_pool='CLIK_SCORING_POOL',
--        ingress_enabled=True,
--        max_instances=2,
--    )
--    # Tunggu service READY (~2-3 menit)

-- 3) Setelah service READY, panggil via SQL (service function)
-- SELECT CLIK_WORKSHOP2.PUBLIC.CLIK_PD_SERVICE!PREDICT_PROBA(...) FROM ...;

-- 4) Panggil via REST API (dari Python/curl)
--    URL: https://<ingress_url>/predict-proba
--    Auth: Authorization: Snowflake Token="<PAT>"
--    Body: {"dataframe_split": {"columns": [...], "data": [[...]]}}
--    Lihat 04b_call_realtime.py untuk contoh lengkap.

-- 5) Cek status service
SHOW SERVICES IN SCHEMA CLIK_WORKSHOP2.PUBLIC;
-- DESCRIBE SERVICE CLIK_PD_SERVICE;
