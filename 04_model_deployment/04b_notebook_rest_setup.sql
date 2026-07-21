/* ============================================================================
   04b - Setup External Access Integration untuk call REST API dari Notebook
   ----------------------------------------------------------------------------
   Agar Snowflake Notebook bisa memanggil endpoint HTTPS publik (SPCS ingress)
   via REST, container notebook butuh External Access Integration (izin egress).

   Versi HOL: TANPA secret. Tiap peserta mengisi PAT masing-masing langsung di
   Cell 1 notebook (PAT_TOKEN = "..."). Hanya network rule + EAI yang diperlukan.
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

-- 2) External Access Integration (cukup network rule, tanpa secret)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION CLIK_SPCS_EAI
  ALLOWED_NETWORK_RULES = (CLIK_SPCS_EGRESS)
  ENABLED = TRUE;

-- 3) Attach EAI ke Notebook:
--    Snowsight Notebook -> "..." -> Notebook settings -> External access
--    integrations -> aktifkan CLIK_SPCS_EAI, lalu restart notebook.
--    Atau via SQL (ganti <NOTEBOOK_NAME>):
-- ALTER NOTEBOOK <NOTEBOOK_NAME> SET EXTERNAL_ACCESS_INTEGRATIONS = (CLIK_SPCS_EAI);

-- 4) Di Cell 1 notebook, tiap peserta mengisi PAT sendiri:
--    PAT_TOKEN = "<PAT masing-masing>"
--    Buat PAT: Snowsight -> profil -> Settings -> Authentication ->
--    Programmatic access tokens -> Generate new token.

-- 5) Cek
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'CLIK_SPCS_EAI';
