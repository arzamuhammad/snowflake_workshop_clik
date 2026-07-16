/* ============================================================================
   CLIK WORKSHOP 2 — 02_generate_subject_features.sql  (AUTO-GENERATED)
   Membuat tabel SUBJECT_FEATURES: 1,000,000 baris x ~200 kolom fitur.
   Dataset sintetis untuk use case Probability of Default (PD) / credit default.
   Dibuat 100% di Snowflake via GENERATOR (tidak perlu upload CSV besar).

   Struktur:
     base  -> id + fitur inti (demografi & ringkasan biro yang MENGGERAKKAN risiko)
     feat  -> ~170 fitur biro tambahան (produk/window/tren/rasio/atribut)
     risk  -> latent logit -> pd_true (probabilitas default sebenarnya)
     final -> default_flag  ~ Bernoulli(pd_true)   (target label)
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE SUBJECT_FEATURES AS
WITH base AS (
  SELECT
    SEQ8()                                             AS rn,
    'SUBJ' || LPAD(SEQ8()::string, 9, '0')             AS subject_id,
    -- ==== fitur inti (correlated dengan default) ====
    FLOOR(UNIFORM(21::float, 65::float, RANDOM()))::int                            AS age,
    CASE WHEN UNIFORM(0::float, 1::float, RANDOM()) < 0.55 THEN 'M' ELSE 'F' END   AS gender,
    ROUND(UNIFORM(3000000::float, 60000000::float, RANDOM()),0)                    AS monthly_income,
    (ARRAY_CONSTRUCT('Karyawan','Wiraswasta','PNS','Profesional','Freelance')
       [FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int])::string                AS employment_type,
    (ARRAY_CONSTRUCT('SMA','D3','S1','S2','SD')
       [FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int])::string                AS education,
    (ARRAY_CONSTRUCT('DKI','JABAR','JATENG','JATIM','BANTEN','YOGYA','BALI','NTB',
        'SUMUT','SUMSEL','RIAU','LAMPUNG','KALTIM','KALBAR','SULSEL','SULUT','PAPUA','MALUKU')
       [FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int])::string               AS region_code,
    FLOOR(UNIFORM(0::float, 3::float, RANDOM()))::int                              AS dependents,
    FLOOR(UNIFORM(0::float, 8::float, RANDOM()))::int                              AS num_active_loans,
    FLOOR(UNIFORM(0::float, 6::float, RANDOM()))::int                              AS num_credit_cards,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int                              AS num_fintech_loans,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int                              AS num_bnpl_accounts,
    FLOOR(UNIFORM(0::float, 12::float, RANDOM()))::int                             AS num_lenders,
    FLOOR(UNIFORM(0::float, 10::float, RANDOM()))::int                             AS num_inquiries_3m,
    FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int                             AS num_inquiries_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 180::float, RANDOM()))::int                  AS max_dpd_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int                  AS max_dpd_24m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 10::float, RANDOM()))::int                   AS num_late_pmt_12m,
    FLOOR(UNIFORM(6::float, 240::float, RANDOM()))::int                            AS oldest_acct_age_months,
    FLOOR(UNIFORM(3::float, 120::float, RANDOM()))::int                            AS avg_acct_age_months,
    ROUND(UNIFORM(0::float, 500000000::float, RANDOM()),0)                         AS total_outstanding,
    ROUND(UNIFORM(5000000::float, 600000000::float, RANDOM()),0)                   AS total_credit_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3)                    AS credit_utilization,
    ROUND(UNIFORM(0::float, 25000000::float, RANDOM()),0)                          AS monthly_installment,
    FLOOR(UNIFORM(1::float, 6::float, RANDOM()))::int                              AS kol_status,   -- Kolektibilitas OJK 1..5
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4)                                 AS u_noise       -- utk Bernoulli draw
  FROM TABLE(GENERATOR(ROWCOUNT => 1000000))
),
feat AS (
  SELECT
    base.*,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS cc_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS cc_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS cc_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS cc_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS cc_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS cc_installment,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS kta_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS kta_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS kta_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS kta_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS kta_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS kta_installment,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS kpr_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS kpr_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS kpr_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS kpr_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS kpr_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS kpr_installment,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS kkb_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS kkb_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS kkb_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS kkb_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS kkb_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS kkb_installment,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS bnpl_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS bnpl_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS bnpl_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS bnpl_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS bnpl_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS bnpl_installment,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS fintech_num_accounts,
    ROUND(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(1000000::float, 300000000::float, RANDOM()),0) AS fintech_outstanding,
    ROUND(UNIFORM(1000000::float, 400000000::float, RANDOM()),0) AS fintech_limit,
    ROUND(LEAST(1.2,UNIFORM(0::float, 1.1::float, RANDOM())),3) AS fintech_util,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 120::float, RANDOM()))::int AS fintech_max_dpd,
    ROUND(UNIFORM(0::float, 15000000::float, RANDOM()),0) AS fintech_installment,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 180::float, RANDOM()))::int AS dpd_max_3m,
    ROUND(UNIFORM(0::float, 60::float, RANDOM()),1) AS dpd_avg_3m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 8::float, RANDOM()))::int AS cnt_late30_3m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 5::float, RANDOM()))::int AS cnt_late60_3m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 4::float, RANDOM()))::int AS cnt_late90_3m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 180::float, RANDOM()))::int AS dpd_max_6m,
    ROUND(UNIFORM(0::float, 60::float, RANDOM()),1) AS dpd_avg_6m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 8::float, RANDOM()))::int AS cnt_late30_6m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 5::float, RANDOM()))::int AS cnt_late60_6m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 4::float, RANDOM()))::int AS cnt_late90_6m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 180::float, RANDOM()))::int AS dpd_max_12m,
    ROUND(UNIFORM(0::float, 60::float, RANDOM()),1) AS dpd_avg_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 8::float, RANDOM()))::int AS cnt_late30_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 5::float, RANDOM()))::int AS cnt_late60_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 4::float, RANDOM()))::int AS cnt_late90_12m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 180::float, RANDOM()))::int AS dpd_max_24m,
    ROUND(UNIFORM(0::float, 60::float, RANDOM()),1) AS dpd_avg_24m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 8::float, RANDOM()))::int AS cnt_late30_24m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 5::float, RANDOM()))::int AS cnt_late60_24m,
    FLOOR(UNIFORM(0::float, 1::float, RANDOM())*UNIFORM(0::float, 4::float, RANDOM()))::int AS cnt_late90_24m,
    FLOOR(UNIFORM(0::float, 6::float, RANDOM()))::int AS inq_bank_3m,
    FLOOR(UNIFORM(0::float, 10::float, RANDOM()))::int AS inq_fintech_3m,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS inq_telco_3m,
    FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int AS inq_total_3m,
    FLOOR(UNIFORM(0::float, 6::float, RANDOM()))::int AS inq_bank_6m,
    FLOOR(UNIFORM(0::float, 10::float, RANDOM()))::int AS inq_fintech_6m,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS inq_telco_6m,
    FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int AS inq_total_6m,
    FLOOR(UNIFORM(0::float, 6::float, RANDOM()))::int AS inq_bank_12m,
    FLOOR(UNIFORM(0::float, 10::float, RANDOM()))::int AS inq_fintech_12m,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS inq_telco_12m,
    FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int AS inq_total_12m,
    FLOOR(UNIFORM(0::float, 6::float, RANDOM()))::int AS inq_bank_24m,
    FLOOR(UNIFORM(0::float, 10::float, RANDOM()))::int AS inq_fintech_24m,
    FLOOR(UNIFORM(0::float, 4::float, RANDOM()))::int AS inq_telco_24m,
    FLOOR(UNIFORM(0::float, 18::float, RANDOM()))::int AS inq_total_24m,
    FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int AS new_acct_3m,
    FLOOR(UNIFORM(0::float, 3::float, RANDOM()))::int AS closed_acct_3m,
    FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int AS new_acct_6m,
    FLOOR(UNIFORM(0::float, 3::float, RANDOM()))::int AS closed_acct_6m,
    FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int AS new_acct_12m,
    FLOOR(UNIFORM(0::float, 3::float, RANDOM()))::int AS closed_acct_12m,
    FLOOR(UNIFORM(0::float, 5::float, RANDOM()))::int AS new_acct_24m,
    FLOOR(UNIFORM(0::float, 3::float, RANDOM()))::int AS closed_acct_24m,
    ROUND(UNIFORM(-0.5::float, 0.5::float, RANDOM()),3) AS util_delta_3m,
    ROUND(UNIFORM(-0.6::float, 0.6::float, RANDOM()),3) AS util_delta_6m,
    ROUND(UNIFORM(-50000000::float, 50000000::float, RANDOM()),3) AS outstanding_delta_3m,
    ROUND(UNIFORM(-80000000::float, 80000000::float, RANDOM()),3) AS outstanding_delta_6m,
    ROUND(UNIFORM(-5000000::float, 5000000::float, RANDOM()),3) AS income_delta_6m,
    ROUND(UNIFORM(-8000000::float, 8000000::float, RANDOM()),3) AS income_delta_12m,
    ROUND(UNIFORM(-3000000::float, 3000000::float, RANDOM()),3) AS installment_delta_6m,
    ROUND(UNIFORM(-20000000::float, 60000000::float, RANDOM()),3) AS limit_delta_12m,
    ROUND(UNIFORM(-0.4::float, 0.6::float, RANDOM()),3) AS balance_growth_3m,
    ROUND(UNIFORM(-0.5::float, 0.8::float, RANDOM()),3) AS balance_growth_6m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS payment_ratio_3m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS payment_ratio_6m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS payment_ratio_12m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS revolving_ratio,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS secured_ratio,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS min_pay_ratio_6m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS overlimit_freq_12m,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS cash_advance_ratio,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS autopay_ratio,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),3) AS ontime_ratio_12m,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_01,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_02,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_03,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_04,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_05,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_06,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_07,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_08,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_09,
    ROUND(UNIFORM(0::float, 100::float, RANDOM()),1) AS bureau_score_comp_10,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_001,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_002,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_003,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_004,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_005,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_006,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_007,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_008,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_009,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_010,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_011,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_012,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_013,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_014,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_015,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_016,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_017,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_018,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_019,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_020,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_021,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_022,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_023,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_024,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_025,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_026,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_027,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_028,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_029,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_030,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_031,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_032,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_033,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_034,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_035,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_036,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_037,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_038,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_039,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_040,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_041,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_042,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_043,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_044,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_045,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_046,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_047,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_048,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_049,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_050,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_051,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_052,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_053,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_054,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_055,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_056,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_057,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_058,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_059,
    ROUND(UNIFORM(0::float, 1::float, RANDOM()),4) AS bureau_attr_060
  FROM base
),
risk AS (
  SELECT
    feat.*,
    /* latent logit: fitur dipusatkan di mean-nya, intercept = logit(~0.10).
       Fitur inti kuat: DPD, utilisasi, inquiry, DTI-proxy, kol_status, fintech, usia(-), income(-).
       Kalibrasi diuji pada sampel 200k -> default rate ~10-12%. */
    (
      -2.50
      + 0.55 * ((max_dpd_12m - 45) / 40.0)
      + 0.30 * ((max_dpd_24m - 30) / 30.0)
      + 0.75 * (credit_utilization - 0.5)
      + 0.45 * ((num_inquiries_12m - 9) / 5.0)
      + 0.30 * (num_fintech_loans - 2)
      + 0.25 * (num_bnpl_accounts - 2)
      + 0.38 * (kol_status - 3)
      + 0.18 * (num_late_pmt_12m - 5)
      + 0.80 * ((monthly_installment / NULLIF(monthly_income,0)) - 0.5)   -- DTI proxy
      - 0.015 * (age - 43)
      - 0.25 * ((monthly_income - 31500000) / 20000000.0)
      - 0.30 * ((avg_acct_age_months - 60) / 40.0)
    )                                                   AS latent_logit,
    1.0 / (1.0 + EXP(-latent_logit))                    AS pd_true
  FROM feat
)
SELECT
  * EXCLUDE (rn, u_noise, latent_logit),
  ROUND(pd_true, 6)                                     AS pd_true_prob,
  IFF(u_noise < pd_true, 1, 0)                          AS default_flag
FROM risk;

-- Ringkasan validasi
SELECT COUNT(*) AS n_rows,
       ROUND(AVG(default_flag),4) AS default_rate,
       ROUND(AVG(pd_true_prob),4) AS avg_pd_true
FROM SUBJECT_FEATURES;
