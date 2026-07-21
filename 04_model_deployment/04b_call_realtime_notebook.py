"""
04b - Real-Time Scoring di Snowflake Notebook (Snowsight HOL)
=============================================================
Versi Hands-On Lab: jalan LANGSUNG di Snowsight Notebook (Container Runtime).
TIDAK butuh PAT, TIDAK butuh external HTTP — semua internal.

Alur (sesuai arsitektur Step 3-5):
  1. Point lookup by PK ke Hybrid Table (SUBJECT_FEATURES_ENCODED_HT)
  2. Panggil model service via SQL service function (CLIK_PD_SERVICE!PREDICT_PROBA)
     ATAU via Model Registry mv.run() (warehouse inference)
  3. Map PD -> credit_score & decision

Prasyarat:
- Jalankan di Snowflake Notebook (Container Runtime atau Warehouse Runtime)
- Service CLIK_PD_SERVICE sudah READY, ATAU model CLIK_PD_MODEL di registry
- Hybrid table SUBJECT_FEATURES_ENCODED_HT sudah ada

Catatan: paste tiap section sebagai cell terpisah di notebook.
"""

# ── Cell 1: Setup ────────────────────────────────────────────────────────────
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col, lit
import time

session = get_active_session()
session.sql("USE DATABASE CLIK_WORKSHOP2").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("ALTER SESSION SET USE_CACHED_RESULT = FALSE").collect()
print("Session ready:", session.get_current_database(), session.get_current_schema())

# ── Cell 2: Step 3 - Point Lookup dari Hybrid Table (Unistore) ───────────────
# Simulasi orkestrasi: terima Subject ID, ambil 60 fitur ter-encode dari
# Precalculated Feature Table (hybrid table) via point lookup by PK.
SUBJECT_IDS = ['SUBJ000000020', 'SUBJ000000044', 'SUBJ000000068']

placeholders = ", ".join([f"'{s}'" for s in SUBJECT_IDS])
t0 = time.perf_counter()
features_sdf = session.sql(f"""
    SELECT *
    FROM SUBJECT_FEATURES_ENCODED_HT
    WHERE SUBJECT_ID IN ({placeholders})
""")
features_pdf = features_sdf.to_pandas()
lookup_ms = (time.perf_counter() - t0) * 1000.0
print(f"[Hybrid Table Lookup] {features_pdf.shape[0]} baris x {features_pdf.shape[1]} kolom "
      f"dalam {lookup_ms:.0f} ms (point lookup by PK)")
features_pdf[['SUBJECT_ID', 'AGE', 'GENDER_F', 'REGION_CODE_DKI', 'DTI_RATIO']].head()

# ── Cell 3: Step 4a - Inference via SQL Service Function (SPCS, internal) ─────
# Panggil model service LANGSUNG via SQL service function — tanpa PAT, tanpa HTTP.
# Ini jalur internal (DNS SPCS) yang paling cepat & secure.
t0 = time.perf_counter()
scored_sdf = session.sql(f"""
    SELECT
        SUBJECT_ID,
        CLIK_PD_SERVICE!PREDICT_PROBA(* EXCLUDE (SUBJECT_ID)):"PREDICT_PROBA_1"::FLOAT AS pd_probability
    FROM SUBJECT_FEATURES_ENCODED_HT
    WHERE SUBJECT_ID IN ({placeholders})
""")
scored_pdf = scored_sdf.to_pandas()
infer_ms = (time.perf_counter() - t0) * 1000.0
print(f"[Service Function] inference dalam {infer_ms:.0f} ms")
scored_pdf['CREDIT_SCORE'] = 300 + (550 * (1 - scored_pdf['PD_PROBABILITY'])).round().astype(int)
scored_pdf['DECISION'] = scored_pdf['PD_PROBABILITY'].apply(
    lambda p: 'APPROVE' if p < 0.10 else ('REVIEW' if p < 0.30 else 'REJECT')
)
scored_pdf[['SUBJECT_ID', 'PD_PROBABILITY', 'CREDIT_SCORE', 'DECISION']]

# ── Cell 4: Step 4b - Alternatif: Inference via Model Registry (Warehouse) ───
# Jika service belum di-deploy, bisa pakai warehouse inference via mv.run().
# Sama hasilnya, tapi jalur berbeda (warehouse, bukan SPCS container).
from snowflake.ml.registry import Registry

reg = Registry(session=session, database_name="CLIK_WORKSHOP2", schema_name="PUBLIC")
mv = reg.get_model("CLIK_PD_MODEL").default

input_sdf = session.sql(f"""
    SELECT * EXCLUDE (SUBJECT_ID)
    FROM SUBJECT_FEATURES_ENCODED_HT
    WHERE SUBJECT_ID IN ({placeholders})
""")
t0 = time.perf_counter()
pred_sdf = mv.run(input_sdf, function_name='predict_proba')
pred_pdf = pred_sdf.to_pandas()
registry_ms = (time.perf_counter() - t0) * 1000.0
print(f"[Registry mv.run] inference dalam {registry_ms:.0f} ms")

# Cari kolom output prediksi (PREDICT_PROBA_1 atau variant)
pred_cols = [c for c in pred_pdf.columns if 'PREDICT_PROBA_1' in c.upper() or 'OUTPUT' in c.upper()]
if pred_cols:
    print("Output columns:", pred_cols)
    print(pred_pdf[pred_cols].head())

# ── Cell 5: Ringkasan Latency ────────────────────────────────────────────────
print("\n=== Ringkasan Latency (in-account, internal) ===")
print(f"  Hybrid Table Lookup (PK)    : {lookup_ms:7.0f} ms")
print(f"  Model Service (SQL function): {infer_ms:7.0f} ms")
print(f"  Model Registry (warehouse)  : {registry_ms:7.0f} ms")
print(f"\n  Total end-to-end (lookup + service): {lookup_ms + infer_ms:.0f} ms")
print("\n  Catatan: angka di atas sudah INTERNAL (in-account, no network RTT).")
print("  Produksi 100M baris: hybrid lookup O(1) by PK index, konsisten di konkurensi tinggi.")
