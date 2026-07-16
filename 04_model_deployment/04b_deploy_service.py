"""
04b - Deploy Model to SPCS for Real-Time Inference
====================================================
Jalankan di Snowflake Notebook (Container Runtime) ATAU lokal dengan snowflake-ml-python.
Sesuai: https://docs.snowflake.com/en/developer-guide/snowflake-ml/inference/real-time-inference-rest-api

Prasyarat:
- Model CLIK_PD_MODEL v1 sudah di Model Registry
- Compute pool CLIK_SCORING_POOL sudah ada (lihat 04b_realtime_spcs.sql)
- snowflake-ml-python >= 1.25.0
"""
from snowflake.snowpark.context import get_active_session
from snowflake.ml.registry import Registry

session = get_active_session()
reg = Registry(session=session, database_name="CLIK_WORKSHOP2", schema_name="PUBLIC")

# Ambil model version object
mv = reg.get_model("CLIK_PD_MODEL").version("V1")

# Deploy sebagai managed service di SPCS.
# gpu_requests=None -> WAJIB untuk model sklearn/xgboost/lightgbm (CPU).
mv.create_service(
    service_name="CLIK_PD_SERVICE",
    service_compute_pool="CLIK_SCORING_POOL",
    ingress_enabled=True,          # WAJIB True untuk memanggil dari luar Snowflake
    gpu_requests=None,             # CPU model
    max_instances=2,               # autoscaling horizontal
    # num_workers=2,               # override jika perlu (default: 2*nCPU+1 utk CPU)
    # image_build_compute_pool=... # opsional: pool lebih kecil utk build image
)
print("Service creation dimulai. CPU model butuh ~5-10 menit sampai READY.")

# Ambil endpoint publik (ingress) & internal
services = mv.list_services()
print(services)
# inference_endpoint = public URL, internal_endpoint = internal DNS

# Cara lain via SQL:
#   SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE;   -> kolom ingress_url
# URL untuk method predict_proba: https://<ingress_url>/predict-proba
