"""
04b - Call Real-Time Model Service via REST API (LOOKUP dari HYBRID TABLE)
=========================================================================
Varian produksi dari 04b_call_realtime.py. Perbedaan: fitur ter-encode diambil
via POINT LOOKUP by PRIMARY KEY ke HYBRID TABLE (Unistore), bukan scan view.

Ini pola "real case" arsitektur real-time decision engine (Step 3):
  terima SUBJECT_ID
  -> POINT LOOKUP by PK ke SUBJECT_FEATURES_ENCODED_HT (Hybrid Table, latensi ms)
  -> POST 60 fitur ke Model Service (SPCS)
  -> baca PD (PREDICT_PROBA_1) -> credit_score & decision.

Kenapa hybrid table (bukan view/standard table)?
  - Precalculated Feature Table 100M Subject ID; lookup 1 baris by PK butuh
    latensi rendah & konkurensi tinggi (100-200 TPS) -> row-store + PK index.
  - View/standard table men-scan micro-partition tiap lookup (tidak skala OLTP).

Prasyarat:
- Hybrid table SUBJECT_FEATURES_ENCODED_HT sudah ada & terisi (PK SUBJECT_ID + 60 fitur)
- Service CLIK_PD_SERVICE sudah READY (lihat 04b_deploy_service.py)
- Personal Access Token (PAT) valid

Menjalankan:
    export SNOWFLAKE_CONNECTION_NAME=ardiyanmuhammad
    export CLIK_INGRESS_URL="<unique-id>-<account>.snowflakecomputing.app"
    export CLIK_PAT="<YOUR_PAT>"
    python 04b_call_realtime_hybrid.py SUBJ000000020 SUBJ000000044
"""
import json
import os
import sys
import time

import pandas as pd
import requests
import snowflake.connector

# -- Konfigurasi (via environment variable) --
CONN_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "default"
INGRESS_URL = os.getenv("CLIK_INGRESS_URL", "<unique-id>-<account>.snowflakecomputing.app")
PAT_TOKEN = os.getenv("CLIK_PAT", "<YOUR_PAT>")

# Method predict_proba -> URL "/predict-proba" (underscore diganti dash)
ENDPOINT_URL = f"https://{INGRESS_URL}/predict-proba"
HEADERS = {
    "Authorization": f'Snowflake Token="{PAT_TOKEN}"',
    "Content-Type": "application/json",
}

# Feature table = HYBRID TABLE (point lookup by PK)
FEATURE_TABLE = "CLIK_WORKSHOP2.PUBLIC.SUBJECT_FEATURES_ENCODED_HT"

# Subject ID yang akan discore (argumen CLI, atau default contoh)
SUBJECT_IDS = sys.argv[1:] or ["SUBJ000000020", "SUBJ000000044", "SUBJ000000068"]


def lookup_features_hybrid(cur, subject_ids):
    """POINT LOOKUP by PRIMARY KEY ke Hybrid Table. Kembalikan (DataFrame 60 fitur, latency_ms)."""
    placeholders = ", ".join(["%s"] * len(subject_ids))
    sql = f"""
        SELECT * EXCLUDE (SUBJECT_ID)
        FROM {FEATURE_TABLE}
        WHERE SUBJECT_ID IN ({placeholders})
    """
    t0 = time.perf_counter()
    cur.execute(sql, tuple(subject_ids))
    cols = [c[0] for c in cur.description]
    rows = cur.fetchall()
    lookup_ms = (time.perf_counter() - t0) * 1000.0
    return pd.DataFrame(rows, columns=cols), lookup_ms


def extract_pd(row_out):
    """row_out = [index, {..fitur.., PREDICT_PROBA_1}] ATAU dict langsung."""
    obj = row_out[1] if isinstance(row_out, list) else row_out
    if isinstance(obj, dict):
        return float(obj["PREDICT_PROBA_1"])
    return float(row_out[-1])


def main():
    conn = snowflake.connector.connect(
        connection_name=CONN_NAME,
        database="CLIK_WORKSHOP2", schema="PUBLIC", warehouse="GEN2_SMALL",
    )
    try:
        cur = conn.cursor()
        cur.execute("ALTER SESSION SET USE_CACHED_RESULT = FALSE")

        # Step 3: point lookup fitur dari Hybrid Table
        df, lookup_ms = lookup_features_hybrid(cur, SUBJECT_IDS)
        print(f"[Hybrid lookup] {df.shape[0]} baris x {df.shape[1]} kolom "
              f"dalam {lookup_ms:.1f} ms (point lookup by PK)")
    finally:
        conn.close()

    # Step 4: POST fitur ke Model Service (dataframe_split WAJIB ada key index)
    split_obj = json.loads(df.to_json(orient="split"))
    payload = {"dataframe_split": split_obj}

    t0 = time.perf_counter()
    resp = requests.post(ENDPOINT_URL, headers=HEADERS, json=payload, timeout=30)
    infer_ms = (time.perf_counter() - t0) * 1000.0
    print(f"[Model serving] HTTP {resp.status_code} dalam {infer_ms:.1f} ms")
    resp.raise_for_status()
    result = resp.json()

    # Step 5: mapping bisnis
    for sid, row_out in zip(SUBJECT_IDS, result["data"]):
        pd_score = extract_pd(row_out)
        credit_score = 300 + round(550 * (1 - pd_score))
        decision = "APPROVE" if pd_score < 0.10 else ("REVIEW" if pd_score < 0.30 else "REJECT")
        print(f"{sid} | PD={pd_score:.4f} | Credit Score={credit_score} | Decision={decision}")


if __name__ == "__main__":
    main()
