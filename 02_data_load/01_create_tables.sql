USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE DIM_REGION (region_code STRING, region_name STRING, island_group STRING);
CREATE OR REPLACE TABLE DIM_PRODUCT (product_code STRING, product_name STRING, product_class STRING);
CREATE OR REPLACE TABLE DIM_LENDER (lender_code STRING, lender_name STRING, lender_type STRING);
CREATE OR REPLACE TABLE LOAN_APPLICATIONS (
  application_id STRING, subject_id STRING, app_date DATE,
  region_code STRING, product_code STRING, lender_code STRING, channel STRING,
  requested_amount NUMBER(18,0), tenor_months NUMBER(5,0), decision STRING
);
