# CLIK Workshop 2 — End-to-End ML, Dashboards & AI Agent on Snowflake

**Customer:** PT CRIF Lembaga Informasi Keuangan (CLIK)
**Duration:** 10:00 – 15:00 (5 hours)
**Use Case:** Credit Default Prediction (Probability of Default)
**Environment:** `CLIK_WORKSHOP2.PUBLIC` · Warehouse `GEN2_SMALL`
**Repo:** https://github.com/arzamuhammad/snowflake_workshop_clik (public)

---

## What You Will Build

| Module | Topic | Snowflake Features |
|--------|-------|--------------------|
| 0 | Environment setup & data loading | Databases, Stages, File Formats, `GENERATOR` |
| 1 | End-to-end Machine Learning | Notebooks (Container Runtime), Model Registry |
| 1b | Model deployment | Batch (Warehouse) + Real-time (SPCS Model Serving) |
| 2 | Dashboard — we write the code | Streamlit in Snowflake, Plotly |
| 3 | Dashboard — AI-assisted with CoCo | Cortex Code prompting |
| 4 | Talk to your data (chatbot) | Cortex Analyst, Cortex Agent, Cowork |

---

## Prerequisites

- Snowflake account with `ACCOUNTADMIN` (or role able to `CREATE DATABASE`, `CREATE COMPUTE POOL`, `BIND SERVICE ENDPOINT`, `CREATE INTEGRATION`)
- Warehouse size `SMALL` or larger
- `snowflake-ml-python >= 1.25.0` (available in Notebooks Container Runtime)
- A web browser (Chrome recommended) — the workshop repo is **public**, so no GitHub account or PAT is needed to pull it
- A Snowflake PAT — for calling the real-time REST endpoint (Module 1b only)

---

# Module 0 — Setup & Data (30 min)

### Step 0.0 — Create a Git Workspace from the public repo

All workshop code (SQL, notebook, Streamlit, agent files) lives in a **public** GitHub repo. The easiest way to bring everything into Snowflake is a **Git Workspace** — it clones the repo directly into Snowsight so you can open the notebook and `COPY FILES` from it without any manual upload.

**Option A — Git Workspace (recommended, UI):**
1. In Snowsight, click **Projects** in the left sidebar → **Workspaces**.
2. Click the **+** button (top right) → **Git Repository**.
3. In the dialog:
   - **Repository URL:** `https://github.com/arzamuhammad/snowflake_workshop_clik.git`
   - **API Integration:** click **+ Create a new API integration**
     - **Integration name:** `CLIK_GIT_API` (must be UPPER CASE)
     - **Allowed domain / prefix:** `github.com`
     - Click **Create**
   - **Public repository:** leave credentials **empty** (the repo is public — no PAT/secret required)
   - **Workspace name:** `workshop_clik` (or your preferred name)
4. Click **Create** and wait for the workspace to sync with the repo.
5. In the workspace file explorer you now see the full repo (`00_setup/`, `02_data_load/`, `03_ml_notebook/`, …). Open any `.sql` file and run it right here, or open the notebook under `03_ml_notebook/`.

> **Tip:** With a Git Workspace, all CSVs, the notebook, and the Streamlit app are available inside Snowflake — no manual file uploads needed. To pull the latest changes later, click the **branch/sync** control in the workspace toolbar.

**After the workspace is ready:**
Open a worksheet (or a SQL cell in the workspace) and run the setup scripts in order (Steps 0.1–0.4). The data-load script **`02_data_load/03_load_from_git.sql`** reads the CSVs straight from the workspace via `COPY FILES INTO ... FROM 'snow://workspace/...'` — no `SECRET` or `GIT REPOSITORY` object required because the workspace already holds every file.

### Step 0.1 — Create database, stages, file format
Run **`00_setup/00_setup.sql`** in a Snowsight worksheet. This creates:
- Database `CLIK_WORKSHOP2`, schema `PUBLIC`
- Internal stages `RAW_DATA_STAGE`, `ML_STAGE`
- File format `CSV_FF`

### Step 0.2 — Create target tables
Run **`02_data_load/01_create_tables.sql`** to create `DIM_REGION`, `DIM_PRODUCT`, `DIM_LENDER`, `LOAN_APPLICATIONS`.

### Step 0.3 — Generate the 1M-row training table
Run **`02_data_load/02_generate_subject_features.sql`**.
This builds `SUBJECT_FEATURES` — **1,000,000 rows × ~196 features** — entirely inside Snowflake using `GENERATOR` (no large file upload). Default rate ≈ 8%. Takes ~15 seconds.

> **Why a script instead of a CSV?** A 1M × 200 CSV would be gigabytes. Generating in-database is faster and teaches `GENERATOR`/`RANDOM` patterns. The small dimension/application CSVs are used to teach the file-loading flow below.

### Step 0.4 — Load CSVs from the Git Workspace → Stage → Table
This is the recommended teaching flow (mirrors the flood-resilience HOL). It assumes you already created the **Git Workspace** in Step 0.0, so all repo files are already fetched into the workspace.

1. Run **`02_data_load/03_load_from_git.sql`** (no edits needed). It will:
   - `COPY FILES` from the workspace path `snow://workspace/USER$.PUBLIC."workshop_clik"/versions/live/` into `RAW_DATA_STAGE`
   - `COPY INTO` the four tables
   - No `SECRET`, `API INTEGRATION`, or `GIT REPOSITORY` object is needed — the workspace already has the files.

> If your workspace name differs from `workshop_clik`, edit the `snow://workspace/...` path in the script accordingly.

**Alternative (no Workspace):** use `PUT file://... @RAW_DATA_STAGE` then `COPY INTO`.

**Validation:**
```sql
SELECT COUNT(*) FROM SUBJECT_FEATURES;    -- 1,000,000
SELECT COUNT(*) FROM LOAN_APPLICATIONS;   -- 50,000
```

---

# Module 1 — End-to-End Machine Learning (120 min)

Open **`03_ml_notebook/01_end_to_end_ml_pd.ipynb`** in **Snowflake Notebooks (Container Runtime)**.

### Step 1.1 — Setup & load data
Cells 1–2: connect the Snowpark session, inspect `SUBJECT_FEATURES`, and pull a sample into pandas.

### Step 1.2 — Feature engineering & split
Cell 3: identify numeric vs categorical columns, build a `ColumnTransformer` (scale numerics, one-hot categoricals), and stratified train/test split.

### Step 1.3 — Model 1: Logistic Regression (Stepwise)
Cells 4: rank features by univariate AUC, then forward-select up to 25 features. Fit the final LR pipeline and report AUC/Gini.

### Step 1.4 — Model 2: XGBoost
Cell 5: train an `XGBClassifier` inside the pipeline with class weighting.

### Step 1.5 — Model 3: LightGBM
Cell 6: train an `LGBMClassifier` with balanced class weights.

### Step 1.6 — Evaluation
Cell 7: compare **AUC, Gini, KS**, plot **ROC curves**, and print the **confusion matrix** + classification report for the best model.

### Step 1.7 — Register to Model Registry
Cell 8: register the best pipeline as **`CLIK_PD_MODEL` version `V1`** with metrics and conda dependencies. The full pipeline (preprocess + classifier) is registered so inference accepts **raw feature columns**.

### Step 1.8 — Test inference from the registry
Cell 9: call `mv.run(..., function_name="predict_proba")` on 10 rows.

**Scaling to 1–5M rows / 1,000–2,000 features:** increase `SAMPLE_ROWS`, use a larger warehouse or a GPU compute pool, and consider `snowflake.ml.modeling` distributed estimators.

---

# Module 1b — Model Deployment

## Batch scoring (Warehouse)
Run **`04_model_deployment/04a_batch_scoring.sql`**:
- Calls the registered model directly from SQL (`CLIK_PD_MODEL!PREDICT_PROBA`)
- Writes results into `SCORE_RESULTS` with credit score (300–850) and decision (APPROVE / REVIEW / REJECT)

## Real-time inference (SPCS Model Serving)
Aligned with the official guide:
https://docs.snowflake.com/en/developer-guide/snowflake-ml/inference/real-time-inference-rest-api

### Step 1b.1 — Compute pool & privilege
Run **`04_model_deployment/04b_realtime_spcs.sql`** (steps 1–2):
```sql
CREATE COMPUTE POOL IF NOT EXISTS CLIK_SCORING_POOL
  MIN_NODES=1 MAX_NODES=2 INSTANCE_FAMILY=CPU_X64_XS AUTO_RESUME=TRUE AUTO_SUSPEND_SECS=300;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE ACCOUNTADMIN;
```

### Step 1b.2 — Deploy the service
Run **`04_model_deployment/04b_deploy_service.py`** in the notebook:
```python
mv = reg.get_model("CLIK_PD_MODEL").version("V1")
mv.create_service(
    service_name="CLIK_PD_SERVICE",
    service_compute_pool="CLIK_SCORING_POOL",
    ingress_enabled=True,   # required for external calls
    gpu_requests=None,      # required for sklearn/xgb/lgbm (CPU)
    max_instances=2,
)
```
> CPU models take ~5–10 minutes to become READY. The endpoint is always named `inference` on port `5000`, and method `predict_proba` maps to URL path `/predict-proba`.

### Step 1b.3 — Get the public endpoint
```sql
SHOW ENDPOINTS IN SERVICE CLIK_PD_SERVICE;   -- read the ingress_url column
```
or in Python: `mv.list_services()` (`inference_endpoint`).

### Step 1b.4 — Call the REST API
Edit **`04_model_deployment/04b_call_realtime.py`** (set `INGRESS_URL` and `PAT_TOKEN`), then run it. It builds the payload the recommended way:
```python
split_obj = json.loads(df.to_json(orient="split"))
payload   = {"dataframe_split": split_obj}
requests.post(f"https://{INGRESS_URL}/predict-proba",
              headers={"Authorization": f'Snowflake Token="{PAT}"',
                       "Content-Type": "application/json"},
              json=payload)
```

**cURL equivalent:**
```bash
curl -X POST "https://<ingress_url>/predict-proba" \
  -H 'Authorization: Snowflake Token="<PAT>"' \
  -H 'Content-Type: application/json' \
  -d '{"dataframe_split": {"index":[0], "columns":["AGE","MONTHLY_INCOME","..."], "data":[[35,15000000,"..."]]}}'
```
> Note: any auth failure or wrong URL returns **HTTP 404** (by design). Use `dataframe_split` (recommended over `dataframe_records`).

---

# Module 2 — Dashboard: We Write the Code (45 min)

1. In Snowsight go to **Projects → Streamlit → + Streamlit App**.
2. Set database `CLIK_WORKSHOP2`, schema `PUBLIC`, warehouse `GEN2_SMALL`.
3. Paste **`05_streamlit_dashboard/clik_dashboard.py`**. Use **`environment.yml`** for packages (plotly, pandas, numpy).
4. Run. The dashboard has 5 tabs covering every required component:
   - **Overview** — colorful KPI cards, application **funnel**, channel **donut**
   - **Time Series** — area & line **time-series** charts with Monthly/Weekly toggle
   - **Heatmap & Cross-Tab** — interactive **cross-tabulation** table + **heatmaps**
   - **Risk Analysis** — default-rate bars, PD histogram, age×utilization **risk heatmap**
   - **Portfolio** — top regions, product mix, stacked-area trend
   - **Interactive filters** throughout (selectbox, radio)

---

# Module 3 — Dashboard with CoCo AI (30 min)

Follow **`06_coco_prompting/prompting_guide.md`**. Attendees rebuild the same dashboard using **Cortex Code** step by step:
1. Setup + KPI cards → 2. Time series → 3. Heatmaps → 4. Cross-tab → 5. Filters → 6. Funnel/Donut → 7. Polish.

The guide includes the exact prompts to type and effective-prompting tips.

---

# Module 4 — Talk to Your Data (45 min)

### Step 4.1 — Create the semantic view
Run **`07_cortex_agent/01_semantic_view.sql`** — creates `CLIK_CREDIT_ANALYTICS` via `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML` (dimensions, time dimension, facts, metrics over both tables).

### Step 4.2 — Create the Cortex Agent
**Preferred (UI):** Snowsight → **AI & ML → Agents → + Create Agent**
- Name `CLIK_ANALYTICS_AGENT`, DB/schema `CLIK_WORKSHOP2.PUBLIC`
- Add an **Analyst tool** pointing to `CLIK_CREDIT_ANALYTICS`
- Paste the instructions from `07_cortex_agent/README.md`

**Alternative (SQL):** `07_cortex_agent/02_create_agent.sql`.

### Step 4.3 — Chat via Snowflake Cowork
Open **Cowork** (chat icon), select the agent, and ask:
- "Show the monthly trend of applications in 2025"
- "What is the default rate by KOL status?"
- "Compare average loan amount across product types"
- "Region mana yang paling banyak reject?" (Indonesian works too)

---

## Data Summary

| Table | Rows | Description |
|-------|------|-------------|
| `SUBJECT_FEATURES` | 1,000,000 | ~196 credit-bureau features + `PD_TRUE_PROB` + `DEFAULT_FLAG` (~8%) |
| `LOAN_APPLICATIONS` | 50,000 | Applications over 18 months (Jan 2025 – Jun 2026) |
| `DIM_REGION` / `DIM_PRODUCT` / `DIM_LENDER` | 18 / 7 / 12 | Reference dimensions |

## Repository Layout
```
workshop_clik/
├── 00_setup/                 00_setup.sql
├── 01_data_generation/       generate_data.py, data/*.csv
├── 02_data_load/             01_create_tables.sql, 02_generate_subject_features.sql, 03_load_from_git.sql
├── 03_ml_notebook/           01_end_to_end_ml_pd.ipynb
├── 04_model_deployment/      04a_batch_scoring.sql, 04b_realtime_spcs.sql, 04b_deploy_service.py, 04b_call_realtime.py
├── 05_streamlit_dashboard/   clik_dashboard.py, environment.yml
├── 06_coco_prompting/        prompting_guide.md
├── 07_cortex_agent/          01_semantic_view.sql, 02_create_agent.sql, README.md
└── README.md                 (this file)
```

## Troubleshooting
- **Service stuck in PENDING** → check `SHOW SERVICE CONTAINERS IN SERVICE CLIK_PD_SERVICE;` and compute pool status.
- **404 on REST call** → wrong PAT, expired token, or wrong ingress URL (auth errors surface as 404).
- **`gpu_requests` error** → sklearn/xgb/lgbm are CPU models; keep `gpu_requests=None`.
- **Model version already exists** → bump `version_name` (e.g., `V2`) in the notebook.
