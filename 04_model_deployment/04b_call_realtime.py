"""
04b - Call Real-Time Model Service via REST API
================================================
Sesuai: https://docs.snowflake.com/en/developer-guide/snowflake-ml/inference/real-time-inference-rest-api

Pola arsitektur (Step 2-5 real-time decision engine):
  terima SUBJECT_ID -> LOOKUP 60 fitur ter-encode -> POST ke Model Service
  -> baca PD (PREDICT_PROBA_1) -> map ke credit_score & decision.

Model CLIK_PD_MODEL (V2_SNOWPARK_ML) dilatih dengan fitur One-Hot Encoding,
jadi payload HARUS berisi 60 fitur ter-encode (bukan kolom mentah). Di sini kita
ambil dari view SUBJECT_FEATURES_ENCODED (lihat 04a_batch_scoring.sql) yang di
produksi bisa diganti point-lookup ke Hybrid Table.

Output service predict_proba: kolom PREDICT_PROBA_0 (P tidak default) &
PREDICT_PROBA_1 (P default = PD score).

Prasyarat:
- Service CLIK_PD_SERVICE sudah READY (lihat 04b_deploy_service.py)
- View SUBJECT_FEATURES_ENCODED sudah ada
- Personal Access Token (PAT) valid

Menjalankan:
    export SNOWFLAKE_CONNECTION_NAME=ardiyanmuhammad
    export CLIK_INGRESS_URL="<unique-id>-<account>.snowflakecomputing.app"
    export CLIK_PAT="<YOUR_PAT>"
    python 04b_call_realtime.py SUBJ000000020 SUBJ000000044
"""
import json
import os
import sys

import pandas as pd
import requests
import snowflake.connector

# -- Konfigurasi (via environment variable) --
CONN_NAME   = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "default"
INGRESS_URL = os.getenv("CLIK_INGRESS_URL", "<unique-id>-<account>.snowflakecomputing.app")
PAT_TOKEN   = os.getenv("CLIK_PAT", "<YOUR_PAT>")

# Method predict_proba -> URL "/predict-proba" (underscore diganti dash)
ENDPOINT_URL = f"https://{INGRESS_URL}/predict-proba"
HEADERS = {
    "Authorization": f'Snowflake Token="{PAT_TOKEN}"',
    "Content-Type": "application/json",
}

# Subject ID yang akan discore (argumen CLI, atau default contoh)
SUBJECT_IDS = sys.argv[1:] or ["SUBJ000000020", "SUBJ000000044", "SUBJ000000068"]


def lookup_encoded_features(subject_ids):
    """Orkestrasi: lookup 60 fitur ter-encode untuk subject_ids (SELECT * EXCLUDE SUBJECT_ID)."""
    conn = snowflake.connector.connect(
        connection_name=CONN_NAME,
        database="CLIK_WORKSHOP2", schema="PUBLIC", warehouse="GEN2_SMALL",
    )
    try:
        placeholders = ", ".join(["%s"] * len(subject_ids))
        sql = f"""
            SELECT * EXCLUDE (SUBJECT_ID)
            FROM CLIK_WORKSHOP2.PUBLIC.SUBJECT_FEATURES_ENCODED
            WHERE SUBJECT_ID IN ({placeholders})
        """
        cur = conn.cursor()
        cur.execute(sql, tuple(subject_ids))
        cols = [c[0] for c in cur.description]
        rows = cur.fetchall()
        return pd.DataFrame(rows, columns=cols)
    finally:
        conn.close()


def main():
    df = lookup_encoded_features(SUBJECT_IDS)
    print(f"Fitur ter-lookup: {df.shape[0]} baris x {df.shape[1]} kolom (harus 60)")

    # Payload dataframe_split (rekomendasi docs)
    split_obj = json.loads(df.to_json(orient="split", index=False))
    payload = {"dataframe_split": split_obj}

    resp = requests.post(ENDPOINT_URL, headers=HEADERS, json=payload, timeout=30)
    print("HTTP Status:", resp.status_code)
    # Catatan docs: kegagalan auth / URL salah -> 404 (tidak bisa dibedakan).
    resp.raise_for_status()
    result = resp.json()

    # Output mengikuti struktur dataframe: {"columns": [...], "data": [[...]]}
    cols = result["columns"]
    for sid, data_row in zip(SUBJECT_IDS, result["data"]):
        row = dict(zip(cols, data_row))
        pd_score = float(row.get("PREDICT_PROBA_1", data_row[-1]))
        credit_score = 300 + round(550 * (1 - pd_score))
        decision = "APPROVE" if pd_score < 0.10 else ("REVIEW" if pd_score < 0.30 else "REJECT")
        print(f"{sid} | PD={pd_score:.4f} | Credit Score={credit_score} | Decision={decision}")


if __name__ == "__main__":
    main()
