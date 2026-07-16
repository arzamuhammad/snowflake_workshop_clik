#!/usr/bin/env python3
"""
CLIK WORKSHOP 2 — Data generator
=================================
A) Small CSVs for the git -> stage -> COPY INTO teaching flow:
     dim_region.csv, dim_product.csv, dim_lender.csv, loan_applications.csv (~50k)
B) SQL script (../02_data_load/02_generate_subject_features.sql) that builds the
     big SUBJECT_FEATURES table (1,000,000 rows x ~200 features) directly in
     Snowflake via GENERATOR (no huge CSV upload).

Run:  python3 generate_data.py
"""
import os
import csv
import random
import datetime as dt

random.seed(42)
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
os.makedirs(DATA, exist_ok=True)
SQL_OUT = os.path.abspath(os.path.join(HERE, "..", "02_data_load", "02_generate_subject_features.sql"))

REGIONS = [
    ("DKI", "DKI Jakarta", "Jawa"), ("JABAR", "Jawa Barat", "Jawa"),
    ("JATENG", "Jawa Tengah", "Jawa"), ("JATIM", "Jawa Timur", "Jawa"),
    ("BANTEN", "Banten", "Jawa"), ("YOGYA", "DI Yogyakarta", "Jawa"),
    ("BALI", "Bali", "Bali-Nusra"), ("NTB", "Nusa Tenggara Barat", "Bali-Nusra"),
    ("SUMUT", "Sumatera Utara", "Sumatera"), ("SUMSEL", "Sumatera Selatan", "Sumatera"),
    ("RIAU", "Riau", "Sumatera"), ("LAMPUNG", "Lampung", "Sumatera"),
    ("KALTIM", "Kalimantan Timur", "Kalimantan"), ("KALBAR", "Kalimantan Barat", "Kalimantan"),
    ("SULSEL", "Sulawesi Selatan", "Sulawesi"), ("SULUT", "Sulawesi Utara", "Sulawesi"),
    ("PAPUA", "Papua", "Indonesia Timur"), ("MALUKU", "Maluku", "Indonesia Timur"),
]
PRODUCTS = [
    ("CC", "Kartu Kredit", "Unsecured"), ("KTA", "Kredit Tanpa Agunan", "Unsecured"),
    ("KPR", "Kredit Pemilikan Rumah", "Secured"), ("KKB", "Kredit Kendaraan Bermotor", "Secured"),
    ("BNPL", "Buy Now Pay Later", "Unsecured"), ("FINTECH", "Pinjaman Fintech P2P", "Unsecured"),
    ("MODAL", "Kredit Modal Kerja", "Secured"),
]
LENDERS = [
    ("BNK001", "Bank Mandiri", "Bank"), ("BNK002", "Bank BCA", "Bank"),
    ("BNK003", "Bank BRI", "Bank"), ("BNK004", "Bank BNI", "Bank"),
    ("BNK005", "Bank CIMB Niaga", "Bank"), ("BNK006", "Bank Danamon", "Bank"),
    ("FIN001", "Kredivo", "Fintech"), ("FIN002", "Akulaku", "Fintech"),
    ("FIN003", "Home Credit", "Multifinance"), ("FIN004", "Adira Finance", "Multifinance"),
    ("FIN005", "AwanTunai", "Fintech"), ("FIN006", "Investree", "Fintech"),
]
CHANNELS = ["Branch", "Mobile App", "Web", "Agent", "Partner"]


def write_csv(name, header, rows):
    path = os.path.join(DATA, name)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  wrote {name:28s} {len(rows):>7,} rows  ({os.path.getsize(path)/1024:.1f} KB)")


def gen_dims():
    write_csv("dim_region.csv", ["region_code", "region_name", "island_group"], REGIONS)
    write_csv("dim_product.csv", ["product_code", "product_name", "product_class"], PRODUCTS)
    write_csv("dim_lender.csv", ["lender_code", "lender_name", "lender_type"], LENDERS)


def gen_applications(n=50000):
    start = dt.date(2025, 1, 1); end = dt.date(2026, 6, 30)
    span = (end - start).days
    rows = []
    region_codes = [r[0] for r in REGIONS]
    product_codes = [p[0] for p in PRODUCTS]
    lender_codes = [l[0] for l in LENDERS]
    region_w = [random.randint(3, 30) for _ in region_codes]
    prod_w = [25, 22, 10, 12, 18, 20, 8]
    for i in range(n):
        app_date = start + dt.timedelta(days=random.randint(0, span))
        region = random.choices(region_codes, weights=region_w)[0]
        product = random.choices(product_codes, weights=prod_w)[0]
        lender = random.choice(lender_codes)
        channel = random.choices(CHANNELS, weights=[20, 40, 20, 10, 10])[0]
        base_amt = {"CC": 15e6, "KTA": 50e6, "KPR": 500e6, "KKB": 200e6,
                    "BNPL": 3e6, "FINTECH": 8e6, "MODAL": 150e6}[product]
        amount = round(base_amt * random.uniform(0.4, 1.8), -4)
        tenor = random.choice([3, 6, 12, 24, 36, 48, 60, 120, 180])
        p_appr = 0.62 + (0.08 if channel in ("Branch", "Agent") else -0.03) \
            + (0.05 if product in ("KPR", "KKB") else -0.04)
        r = random.random()
        decision = "APPROVE" if r < p_appr else ("REVIEW" if r < p_appr + 0.15 else "REJECT")
        subject_id = "SUBJ" + str(random.randint(0, 999999)).zfill(9)
        rows.append(["APP" + str(i).zfill(8), subject_id, app_date.isoformat(),
                     region, product, lender, channel, f"{amount:.0f}", tenor, decision])
    write_csv("loan_applications.csv",
              ["application_id", "subject_id", "app_date", "region_code", "product_code",
               "lender_code", "channel", "requested_amount", "tenor_months", "decision"], rows)


def _u(lo, hi):
    """UNIFORM continuous — float args are important (integer args return only 0/1)."""
    return f"UNIFORM({lo}::float, {hi}::float, RANDOM())"


def build_sql(rowcount=1_000_000):
    products = ["cc", "kta", "kpr", "kkb", "bnpl", "fintech"]
    windows = [3, 6, 12, 24]
    cols = []
    for p in products:
        cols.append((f"{p}_num_accounts", f"FLOOR({_u(0,4)})::int"))
        cols.append((f"{p}_outstanding", f"ROUND({_u(0,1)}*{_u(1000000,300000000)},0)"))
        cols.append((f"{p}_limit", f"ROUND({_u(1000000,400000000)},0)"))
        cols.append((f"{p}_util", f"ROUND(LEAST(1.2,{_u(0,1.1)}),3)"))
        cols.append((f"{p}_max_dpd", f"FLOOR({_u(0,1)}*{_u(0,120)})::int"))
        cols.append((f"{p}_installment", f"ROUND({_u(0,15000000)},0)"))
    for w in windows:
        cols.append((f"dpd_max_{w}m", f"FLOOR({_u(0,1)}*{_u(0,180)})::int"))
        cols.append((f"dpd_avg_{w}m", f"ROUND({_u(0,60)},1)"))
        cols.append((f"cnt_late30_{w}m", f"FLOOR({_u(0,1)}*{_u(0,8)})::int"))
        cols.append((f"cnt_late60_{w}m", f"FLOOR({_u(0,1)}*{_u(0,5)})::int"))
        cols.append((f"cnt_late90_{w}m", f"FLOOR({_u(0,1)}*{_u(0,4)})::int"))
    for w in windows:
        cols.append((f"inq_bank_{w}m", f"FLOOR({_u(0,6)})::int"))
        cols.append((f"inq_fintech_{w}m", f"FLOOR({_u(0,10)})::int"))
        cols.append((f"inq_telco_{w}m", f"FLOOR({_u(0,4)})::int"))
        cols.append((f"inq_total_{w}m", f"FLOOR({_u(0,18)})::int"))
    for w in windows:
        cols.append((f"new_acct_{w}m", f"FLOOR({_u(0,5)})::int"))
        cols.append((f"closed_acct_{w}m", f"FLOOR({_u(0,3)})::int"))
    for nm, lo, hi in [
        ("util_delta_3m", -0.5, 0.5), ("util_delta_6m", -0.6, 0.6),
        ("outstanding_delta_3m", -50000000, 50000000), ("outstanding_delta_6m", -80000000, 80000000),
        ("income_delta_6m", -5000000, 5000000), ("income_delta_12m", -8000000, 8000000),
        ("installment_delta_6m", -3000000, 3000000), ("limit_delta_12m", -20000000, 60000000),
        ("balance_growth_3m", -0.4, 0.6), ("balance_growth_6m", -0.5, 0.8),
    ]:
        cols.append((nm, f"ROUND({_u(lo,hi)},3)"))
    for nm in ["payment_ratio_3m", "payment_ratio_6m", "payment_ratio_12m",
               "revolving_ratio", "secured_ratio", "min_pay_ratio_6m",
               "overlimit_freq_12m", "cash_advance_ratio", "autopay_ratio", "ontime_ratio_12m"]:
        cols.append((nm, f"ROUND({_u(0,1)},3)"))
    for i in range(1, 11):
        cols.append((f"bureau_score_comp_{i:02d}", f"ROUND({_u(0,100)},1)"))
    existing = len(cols); core_named = 30; target = 200
    n_generic = max(0, target - existing - core_named)
    for i in range(1, n_generic + 1):
        cols.append((f"bureau_attr_{i:03d}", f"ROUND({_u(0,1)},4)"))

    feat_lines = ",\n    ".join(f"{expr} AS {name}" for name, expr in cols)
    sql = f"""/* AUTO-GENERATED — CLIK WORKSHOP 2 — SUBJECT_FEATURES ({rowcount:,} rows x ~{len(cols)+core_named} cols)
   Synthetic Probability-of-Default dataset, generated entirely in Snowflake via GENERATOR. */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE SUBJECT_FEATURES AS
WITH base AS (
  SELECT
    SEQ8() AS rn,
    'SUBJ' || LPAD(SEQ8()::string, 9, '0') AS subject_id,
    FLOOR({_u(21,65)})::int AS age,
    CASE WHEN {_u(0,1)} < 0.55 THEN 'M' ELSE 'F' END AS gender,
    ROUND({_u(3000000,60000000)},0) AS monthly_income,
    (ARRAY_CONSTRUCT('Karyawan','Wiraswasta','PNS','Profesional','Freelance')[FLOOR({_u(0,5)})::int])::string AS employment_type,
    (ARRAY_CONSTRUCT('SMA','D3','S1','S2','SD')[FLOOR({_u(0,5)})::int])::string AS education,
    (ARRAY_CONSTRUCT('DKI','JABAR','JATENG','JATIM','BANTEN','YOGYA','BALI','NTB','SUMUT','SUMSEL','RIAU','LAMPUNG','KALTIM','KALBAR','SULSEL','SULUT','PAPUA','MALUKU')[FLOOR({_u(0,18)})::int])::string AS region_code,
    FLOOR({_u(0,3)})::int AS dependents,
    FLOOR({_u(0,8)})::int AS num_active_loans,
    FLOOR({_u(0,6)})::int AS num_credit_cards,
    FLOOR({_u(0,4)})::int AS num_fintech_loans,
    FLOOR({_u(0,4)})::int AS num_bnpl_accounts,
    FLOOR({_u(0,12)})::int AS num_lenders,
    FLOOR({_u(0,10)})::int AS num_inquiries_3m,
    FLOOR({_u(0,18)})::int AS num_inquiries_12m,
    FLOOR({_u(0,1)}*{_u(0,180)})::int AS max_dpd_12m,
    FLOOR({_u(0,1)}*{_u(0,120)})::int AS max_dpd_24m,
    FLOOR({_u(0,10)})::int AS num_late_pmt_12m,
    FLOOR({_u(6,240)})::int AS oldest_acct_age_months,
    FLOOR({_u(3,120)})::int AS avg_acct_age_months,
    ROUND({_u(0,500000000)},0) AS total_outstanding,
    ROUND({_u(5000000,600000000)},0) AS total_credit_limit,
    ROUND(LEAST(1.2,{_u(0,1.1)}),3) AS credit_utilization,
    ROUND({_u(0,25000000)},0) AS monthly_installment,
    FLOOR({_u(1,6)})::int AS kol_status,
    ROUND({_u(0,1)},4) AS u_noise
  FROM TABLE(GENERATOR(ROWCOUNT => {rowcount}))
),
feat AS (
  SELECT base.*,
    {feat_lines}
  FROM base
),
risk AS (
  SELECT feat.*,
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
      + 0.80 * ((monthly_installment / NULLIF(monthly_income,0)) - 0.5)
      - 0.015 * (age - 43)
      - 0.25 * ((monthly_income - 31500000) / 20000000.0)
      - 0.30 * ((avg_acct_age_months - 60) / 40.0)
    ) AS latent_logit,
    1.0 / (1.0 + EXP(-latent_logit)) AS pd_true
  FROM feat
)
SELECT
  * EXCLUDE (rn, u_noise, latent_logit),
  ROUND(pd_true, 6) AS pd_true_prob,
  IFF(u_noise < pd_true, 1, 0) AS default_flag
FROM risk;

SELECT COUNT(*) AS n_rows, ROUND(AVG(default_flag),4) AS default_rate FROM SUBJECT_FEATURES;
"""
    with open(SQL_OUT, "w") as f:
        f.write(sql)
    print(f"  wrote SQL generator -> {SQL_OUT} ({len(cols)} feat cols + ~{core_named} core)")


if __name__ == "__main__":
    print("Generating small CSVs ...")
    gen_dims()
    gen_applications(50000)
    print("Generating big-table SQL ...")
    build_sql(1_000_000)
    print("Done.")
