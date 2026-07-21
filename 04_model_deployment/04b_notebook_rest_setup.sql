/* ============================================================================
   04b - Setup External Access Integration untuk call REST API dari Notebook
   ----------------------------------------------------------------------------
   Agar Snowflake Notebook (Container Runtime) bisa memanggil endpoint HTTPS
   publik (SPCS ingress) via REST, container butuh External Access Integration:
   network rule (egress) + secret (PAT).
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) Network rule: izinkan egress ke host ingress service
--    Ganti host sesuai output: SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE;
CREATE OR REPLACE NETWORK RULE CLIK_SPCS_EGRESS
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('i4ot-sfseapac-ardiyanmuhammad.snowflakecomputing.app');

-- 2) Secret: simpan PAT (JANGAN hardcode di kode notebook)
--    Ganti dengan PAT valid milik Anda.
CREATE OR REPLACE SECRET CLIK_PD_PAT
  TYPE = GENERIC_STRING
  SECRET_STRING = '<YOUR_PAT>';

-- 3) External Access Integration: gabungkan network rule + secret
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION CLIK_SPCS_EAI
  ALLOWED_NETWORK_RULES = (CLIK_SPCS_EGRESS)
  ALLOWED_AUTHENTICATION_SECRETS = (CLIK_PD_PAT)
  ENABLED = TRUE;

-- 4) Attach EAI ke Notebook:
--    Snowsight Notebook -> "..." -> Notebook settings -> External access
--    integrations -> aktifkan CLIK_SPCS_EAI, lalu restart notebook.
--    Atau via SQL (ganti <NOTEBOOK_NAME>):
-- ALTER NOTEBOOK <NOTEBOOK_NAME> SET EXTERNAL_ACCESS_INTEGRATIONS = (CLIK_SPCS_EAI);

-- 5) Cek
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'CLIK_SPCS_EAI';
