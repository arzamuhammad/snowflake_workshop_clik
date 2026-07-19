/* ============================================================================
   CLIK WORKSHOP 2 — 03_load_from_git.sql
   ASUMSI: Anda sudah membuat GIT WORKSPACE dari repo public (lihat README Step 0.0),
   sehingga semua file repo sudah ter-fetch ke workspace.
   POLA: COPY FILES dari workspace -> internal stage -> COPY INTO table.
   (Tidak perlu SECRET / API INTEGRATION / GIT REPOSITORY object.)

   Nama workspace default = "workshop_clik". Path file CSV di dalam repo =
   workshop_clik/01_data_generation/data/*.csv
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- 1) Copy CSV dari GIT WORKSPACE (versions/live) ke internal stage
COPY FILES INTO @RAW_DATA_STAGE/
FROM 'snow://workspace/USER$.PUBLIC."workshop_clik"/versions/live/'
FILES=(
  'workshop_clik/01_data_generation/data/dim_region.csv',
  'workshop_clik/01_data_generation/data/dim_product.csv',
  'workshop_clik/01_data_generation/data/dim_lender.csv',
  'workshop_clik/01_data_generation/data/loan_applications.csv'
);

LS @RAW_DATA_STAGE/;

-- 2) COPY INTO tables
COPY INTO DIM_REGION FROM @RAW_DATA_STAGE/dim_region.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO DIM_PRODUCT FROM @RAW_DATA_STAGE/dim_product.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO DIM_LENDER FROM @RAW_DATA_STAGE/dim_lender.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;
COPY INTO LOAN_APPLICATIONS FROM @RAW_DATA_STAGE/loan_applications.csv FILE_FORMAT=(FORMAT_NAME=CSV_FF) FORCE=TRUE;

-- 3) Validasi
SELECT 'DIM_REGION' t, COUNT(*) n FROM DIM_REGION
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL SELECT 'DIM_LENDER', COUNT(*) FROM DIM_LENDER
UNION ALL SELECT 'LOAN_APPLICATIONS', COUNT(*) FROM LOAN_APPLICATIONS;
