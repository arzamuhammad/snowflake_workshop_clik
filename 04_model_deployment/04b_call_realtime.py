"""
04b - Call Real-Time Model Service via REST API
Prerequisite: CLIK_PD_SERVICE sudah READY (dari 04b_realtime_spcs.sql / notebook)
"""
import requests
import json

INGRESS_URL = "https://<YOUR_INGRESS_URL>"  # Dari SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE
PAT_TOKEN = "<YOUR_PAT>"  # Snowflake Personal Access Token

FEATURES = ["AGE", "MONTHLY_INCOME", "NUM_ACTIVE_LOANS", "CREDIT_UTILIZATION",
            "MAX_DPD_12M", "NUM_INQUIRIES_12M", "KOL_STATUS"]  # subset; gunakan semua fitur

sample_data = [[35, 15000000, 3, 0.45, 0, 2, 1]]

payload = {
    "dataframe_split": {
        "columns": FEATURES,
        "data": sample_data
    }
}

headers = {
    "Authorization": f'Snowflake Token="{PAT_TOKEN}"',
    "Content-Type": "application/json",
}

resp = requests.post(f"{INGRESS_URL}/predict-proba", headers=headers, json=payload)
print("Status:", resp.status_code)
print("Response:", json.dumps(resp.json(), indent=2))

pd_score = resp.json()["data"][0][0]
credit_score = 300 + round(550 * (1 - pd_score))
decision = "APPROVE" if pd_score < 0.10 else ("REVIEW" if pd_score < 0.30 else "REJECT")
print(f"\nPD: {pd_score:.4f} | Credit Score: {credit_score} | Decision: {decision}")
