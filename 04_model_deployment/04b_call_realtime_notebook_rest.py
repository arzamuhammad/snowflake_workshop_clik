"""
04b - Call Model via REST API DARI DALAM Snowflake Notebook (Snowsight)
=======================================================================
Showcase: memanggil SPCS model service via REST API dari dalam Snowflake Notebook
(Container Runtime), memakai External Access Integration (EAI) + Secret (PAT).

Kenapa perlu EAI?
  Notebook (container) memanggil endpoint HTTPS publik (ingress) = egress ke luar,
  jadi butuh External Access Integration yang mengizinkan host + menyimpan PAT
  sebagai secret (tidak hardcode di kode).

=== SETUP SEKALI (sudah dibuat, lihat 04b_notebook_rest_setup.sql) ===
  NETWORK RULE  CLIK_SPCS_EGRESS  (egress ke host ingress)
  SECRET        CLIK_PD_PAT       (PAT)
  EAI           CLIK_SPCS_EAI     (network rule + secret)

=== ATTACH KE NOTEBOOK (WAJIB) ===
  Di Snowsight Notebook -> menu kanan atas "..." -> Notebook settings ->
  "External access integrations" -> aktifkan CLIK_SPCS_EAI. Restart notebook.
  (Atau via SQL: ALTER NOTEBOOK <nb> SET EXTERNAL_ACCESS_INTEGRATIONS=(CLIK_SPCS_EAI);)

Catatan: paste tiap section sebagai cell terpisah.
"""

# ── Cell 1: Ambil ingress URL & PAT (dari secret) ────────────────────────────
import _snowflake                      # modul bawaan notebook untuk baca secret
import json
import requests
from snowflake.snowpark.context import get_active_session

session = get_active_session()

# Ingress URL diambil dinamis dari service (tidak hardcode)
ep = session.sql("SHOW ENDPOINTS IN SERVICE CLIK_WORKSHOP2.PUBLIC.CLIK_PD_SERVICE").collect()
INGRESS_URL = ep[0]["ingress_url"]
ENDPOINT_URL = f"https://{INGRESS_URL}/predict-proba"

# PAT dibaca dari SECRET via EAI (BUKAN hardcode). Nama = nama secret di EAI.
PAT_TOKEN = _snowflake.get_generic_secret_string("CLIK_PD_PAT")

HEADERS = {
    "Authorization": f'Snowflake Token="{PAT_TOKEN}"',
    "Content-Type": "application/json",
}
print("Endpoint:", ENDPOINT_URL)

# ── Cell 2: Point lookup fitur dari Hybrid Table ─────────────────────────────
SUBJECT_IDS = ['SUBJ000000020', 'SUBJ000000044', 'SUBJ000000068']
placeholders = ", ".join([f"'{s}'" for s in SUBJECT_IDS])

df = session.sql(f"""
    SELECT * EXCLUDE (SUBJECT_ID)
    FROM CLIK_WORKSHOP2.PUBLIC.SUBJECT_FEATURES_ENCODED_HT
    WHERE SUBJECT_ID IN ({placeholders})
""").to_pandas()
print(f"Fitur ter-lookup: {df.shape[0]} baris x {df.shape[1]} kolom")

# ── Cell 3: Panggil REST API (dari dalam notebook, lewat EAI) ────────────────
# Payload dataframe_split WAJIB menyertakan key index -> df.to_json(orient="split")
split_obj = json.loads(df.to_json(orient="split"))
payload = {"dataframe_split": split_obj}

resp = requests.post(ENDPOINT_URL, headers=HEADERS, json=payload, timeout=30)
print("HTTP Status:", resp.status_code)
resp.raise_for_status()
result = resp.json()

# ── Cell 4: Mapping bisnis (PD -> credit score -> decision) ──────────────────
def extract_pd(row_out):
    obj = row_out[1] if isinstance(row_out, list) else row_out
    return float(obj["PREDICT_PROBA_1"]) if isinstance(obj, dict) else float(row_out[-1])

for sid, row_out in zip(SUBJECT_IDS, result["data"]):
    pd_score = extract_pd(row_out)
    credit_score = 300 + round(550 * (1 - pd_score))
    decision = "APPROVE" if pd_score < 0.10 else ("REVIEW" if pd_score < 0.30 else "REJECT")
    print(f"{sid} | PD={pd_score:.4f} | Credit Score={credit_score} | Decision={decision}")
