/* ============================================================================
   CLIK WORKSHOP 2 — 03_load_from_git.sql
   POLA YANG DIAJARKAN: Git Repository -> COPY FILES ke stage -> COPY INTO table
   Repo bersifat PUBLIC, jadi TIDAK perlu SECRET / GitHub PAT.
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) API integration (public repo -> tanpa ALLOWED_AUTHENTICATION_SECRETS)
CREATE OR REPLACE API INTEGRATION CLIK_GIT_API
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ('https://github.com/arzamuhammad')
  ENABLED = TRUE;

-- 2) Git Repository object (public -> tanpa GIT_CREDENTIALS)
CREATE OR REPLACE GIT REPOSITORY CLIK_WORKSHOP_REPO
  API_INTEGRATION = CLIK_GIT_API
  ORIGIN = 'https://github.com/arzamuhammad/snowflake_workshop_clik.git';

-- 3) Fetch
ALTER GIT REPOSITORY CLIK_WORKSHOP_REPO FETCH;
LS @CLIK_WORKSHOP_REPO/branches/main/workshop_clik/01_data_generation/data/;

-- 4) Copy files dari git repo ke internal stage
COPY FILES INTO @RAW_DATA_STAGE/
  FROM @CLIK_WORKSHOP_REPO/branches/main/workshop_clik/01_data_generation/data/;

-- 5) COPY INTO tables
COPY INTO DIM_REGION FROM @RAW_DATA_STAGE/dim_region.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO DIM_PRODUCT FROM @RAW_DATA_STAGE/dim_product.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO DIM_LENDER FROM @RAW_DATA_STAGE/dim_lender.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO LOAN_APPLICATIONS FROM @RAW_DATA_STAGE/loan_applications.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;

-- 6) Validasi
SELECT 'DIM_REGION' t, COUNT(*) n FROM DIM_REGION
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL SELECT 'DIM_LENDER', COUNT(*) FROM DIM_LENDER
UNION ALL SELECT 'LOAN_APPLICATIONS', COUNT(*) FROM LOAN_APPLICATIONS;
