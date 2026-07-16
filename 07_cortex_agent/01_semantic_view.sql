/* ============================================================================
   07 — Cortex Analyst: Semantic View + Cortex Agent
   Membuat semantic view untuk Cortex Analyst -> digunakan oleh Cortex Agent
   sebagai tool "talk to your data".
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

-- Semantic View mendefinisikan model semantik atas tabel-tabel kita.
-- Dibangun via Snowflake Workspaces > Add New > Semantic View (UI),
-- atau via YAML DDL di bawah ini.

-- Gunakan SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML (DDL yang benar)
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'CLIK_WORKSHOP2.PUBLIC',
  $$
name: CLIK_CREDIT_ANALYTICS
tables:
  - name: LOAN_APPLICATIONS
    base_table:
      database: CLIK_WORKSHOP2
      schema: PUBLIC
      table: LOAN_APPLICATIONS
    dimensions:
      - name: application_id
        expr: APPLICATION_ID
        description: Unique application identifier
      - name: subject_id
        expr: SUBJECT_ID
        description: Credit bureau subject ID
      - name: region
        expr: REGION_CODE
        description: Province/region code (DKI, JABAR, JATIM, etc.)
      - name: product
        expr: PRODUCT_CODE
        description: Loan product type (CC, KTA, KPR, KKB, BNPL, FINTECH, MODAL)
      - name: lender
        expr: LENDER_CODE
        description: Lender/bank code
      - name: channel
        expr: CHANNEL
        description: Application channel (Branch, Mobile App, Web, Agent, Partner)
      - name: decision
        expr: DECISION
        description: Application decision (APPROVE, REJECT, REVIEW)
    time_dimensions:
      - name: application_date
        expr: APP_DATE
        description: Date application was submitted
    measures:
      - name: total_applications
        expr: COUNT(APPLICATION_ID)
        description: Total number of loan applications
      - name: approval_rate
        expr: AVG(CASE WHEN DECISION='APPROVE' THEN 1.0 ELSE 0.0 END)
        description: Approval rate (ratio of approved applications)
      - name: avg_loan_amount
        expr: AVG(REQUESTED_AMOUNT)
        description: Average requested loan amount in IDR
      - name: total_loan_amount
        expr: SUM(REQUESTED_AMOUNT)
        description: Total requested loan amount in IDR
      - name: avg_tenor
        expr: AVG(TENOR_MONTHS)
        description: Average loan tenor in months

  - name: SUBJECT_FEATURES
    base_table:
      database: CLIK_WORKSHOP2
      schema: PUBLIC
      table: SUBJECT_FEATURES
    dimensions:
      - name: subject_id
        expr: SUBJECT_ID
        description: Unique credit bureau subject identifier
      - name: gender
        expr: GENDER
        description: Gender (M/F)
      - name: employment_type
        expr: EMPLOYMENT_TYPE
        description: Employment type (Karyawan, Wiraswasta, PNS, Profesional, Freelance)
      - name: education
        expr: EDUCATION
        description: Education level (SD, SMA, D3, S1, S2)
      - name: region
        expr: REGION_CODE
        description: Province/region code
      - name: kol_status
        expr: KOL_STATUS
        description: OJK collectibility status (1=lancar to 5=macet)
      - name: default_flag
        expr: DEFAULT_FLAG
        description: Whether subject defaulted (1=yes, 0=no)
    measures:
      - name: total_subjects
        expr: COUNT(SUBJECT_ID)
        description: Total number of credit bureau subjects
      - name: default_rate
        expr: AVG(DEFAULT_FLAG)
        description: Default rate (proportion of defaulted subjects)
      - name: avg_pd
        expr: AVG(PD_TRUE_PROB)
        description: Average probability of default
      - name: avg_income
        expr: AVG(MONTHLY_INCOME)
        description: Average monthly income in IDR
      - name: avg_utilization
        expr: AVG(CREDIT_UTILIZATION)
        description: Average credit utilization ratio
      - name: avg_dti
        expr: AVG(MONTHLY_INSTALLMENT / NULLIF(MONTHLY_INCOME, 0))
        description: Average debt-to-income ratio
      - name: avg_dpd_12m
        expr: AVG(MAX_DPD_12M)
        description: Average max days past due in last 12 months
      - name: avg_num_loans
        expr: AVG(NUM_ACTIVE_LOANS)
        description: Average number of active loans per subject
$$,
  FALSE
);

-- Verifikasi
DESCRIBE SEMANTIC VIEW CLIK_WORKSHOP2.PUBLIC.CLIK_CREDIT_ANALYTICS;
