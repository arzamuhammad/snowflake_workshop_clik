"""
04b - Call Real-Time Model Service via REST API
================================================
Sesuai: https://docs.snowflake.com/en/developer-guide/snowflake-ml/inference/real-time-inference-rest-api

Prasyarat:
- Service CLIK_PD_SERVICE sudah READY (lihat 04b_deploy_service.py)
- Personal Access Token (PAT) valid

Menjalankan:
    python 04b_call_realtime.py
"""
import json
import pandas as pd
import requests

# ── Konfigurasi ──────────────────────────────────────────────────────────────
# Ambil ingress_url dari: SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE;
# atau mv.list_services() (kolom inference_endpoint)
INGRESS_URL = "<unique-id>-<account>.snowflakecomputing.app"
PAT_TOKEN   = "<YOUR_PAT>"

# Method predict_proba -> URL "/predict-proba" (underscore diganti dash)
ENDPOINT_URL = f"https://{INGRESS_URL}/predict-proba"

HEADERS = {
    "Authorization": f'Snowflake Token="{PAT_TOKEN}"',
    "Content-Type": "application/json",
}

# ── Data input ───────────────────────────────────────────────────────────────
# PENTING: kolom HARUS sama persis dengan fitur yang dipakai model saat register.
# Untuk model XGBoost/LightGBM full pipeline, gunakan SEMUA kolom fitur (FEATURES).
# Contoh minimal (ganti dengan seluruh fitur nyata dari SUBJECT_FEATURES):
df = pd.DataFrame([
    {
        "AGE": 35, "MONTHLY_INCOME": 15000000, "NUM_ACTIVE_LOANS": 3,
        "CREDIT_UTILIZATION": 0.45, "MAX_DPD_12M": 0, "NUM_INQUIRIES_12M": 2,
        "KOL_STATUS": 1, "GENDER": "M", "EMPLOYMENT_TYPE": "Karyawan",
        "EDUCATION": "S1", "REGION_CODE": "DKI",
        # ... tambahkan sisa kolom fitur sesuai signature model ...
    }
])

# ── Bangun payload dengan pandas to_json (rekomendasi docs) ─────────────────────
split_obj = json.loads(df.to_json(orient="split"))
payload = {"dataframe_split": split_obj}

# ── Kirim request ────────────────────────────────────────────────────────────
resp = requests.post(ENDPOINT_URL, headers=HEADERS, json=payload, timeout=30)
print("HTTP Status:", resp.status_code)
# Catatan docs: kegagalan auth / URL salah -> 404 (tidak bisa dibedakan).
resp.raise_for_status()
result = resp.json()
print("Response:", json.dumps(result, indent=2))

# ── Interpretasi output ──────────────────────────────────────────────────────
# Output mengikuti struktur dataframe (index/columns/data). Kolom probabilitas
# kelas-1 biasanya "output_feature_1" (predict_proba mengembalikan 2 kolom).
try:
    cols = result["columns"]
    data = result["data"][0]
    row = dict(zip(cols, data))
    pd_score = float(row.get("output_feature_1", data[-1]))
except Exception:
    pd_score = float(result["data"][0][-1])

credit_score = 300 + round(550 * (1 - pd_score))
decision = "APPROVE" if pd_score < 0.10 else ("REVIEW" if pd_score < 0.30 else "REJECT")
print(f"\nPD: {pd_score:.4f} | Credit Score: {credit_score} | Decision: {decision}")
