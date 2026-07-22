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
   - **Workspace name:** `snowflake_workshop_clik` (defaults to the repo name; keep it to match the load script)
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
   - `COPY FILES` from the workspace path `snow://workspace/USER$.PUBLIC."snowflake_workshop_clik"/versions/live/` into `RAW_DATA_STAGE` (CSVs live at `01_data_generation/data/`)
   - `COPY INTO` the four tables
   - No `SECRET`, `API INTEGRATION`, or `GIT REPOSITORY` object is needed — the workspace already has the files.

> If your workspace name differs from `snowflake_workshop_clik`, edit the `snow://workspace/...` path in the script accordingly. Tip: run `LS 'snow://workspace/USER$.PUBLIC."snowflake_workshop_clik"/versions/live/';` to confirm the exact file paths.

**Alternative (no Workspace):** use `PUT file://... @RAW_DATA_STAGE` then `COPY INTO`.

**Validation:**
```sql
SELECT COUNT(*) FROM SUBJECT_FEATURES;    -- 1,000,000
SELECT COUNT(*) FROM LOAN_APPLICATIONS;   -- 50,000
```

---

# Module 1 — End-to-End Machine Learning (120 min)

The ML notebook runs on **Container Runtime**, which needs a **compute pool** and a notebook **runtime service**. Set these up first, then open the notebook from your Git Workspace.

### Step 1.0 — Create a compute pool & run the notebook on a container service

**a) Create the compute pool** (run once in a worksheet or SQL cell):
```sql
USE ROLE ACCOUNTADMIN;
CREATE COMPUTE POOL IF NOT EXISTS CLIK_NOTEBOOK_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_M      -- use a GPU family (e.g. GPU_NV_S) only if training on GPU
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;

-- privileges so the notebook can run on the pool and reach the internet for pip installs
GRANT USAGE ON COMPUTE POOL CLIK_NOTEBOOK_POOL TO ROLE ACCOUNTADMIN;
```

**b) Open the notebook from the Git Workspace**
1. In your workspace (Step 0.0), open **`03_ml_notebook/01_end_to_end_ml_pd.ipynb`**.
2. When prompted to select a runtime, choose **Run on container** and pick:
   - **Compute pool:** `CLIK_NOTEBOOK_POOL`
   - **Runtime:** a Container Runtime for ML image (default is fine)
   - **Query warehouse:** `GEN2_SMALL`
3. Click **Create / Connect** and wait ~1–3 minutes for the notebook service to become **Active**.
4. Set the notebook context — **Database** `CLIK_WORKSHOP2`, **Schema** `PUBLIC`.
5. Run the **first code cell** — it prints the installed `snowflake-ml-python` version and only `!pip install --upgrade` it if it's below `1.25.0`.

> **Packages on Container Runtime:** the base image already includes `snowflake-ml-python`, `snowpark`, `scikit-learn`, `xgboost`, `lightgbm`, `pandas`, `numpy`, `matplotlib`, so the training cells need no install. Extra/upgraded packages are installed with **`!pip install`** in a cell (Snowflake serves them from an internal PyPI mirror — no external access needed) — **not** via the Anaconda "Packages" dropdown, which only applies to Warehouse-runtime notebooks. We only upgrade `snowflake-ml-python` when the printed version is below `1.25.0` (required by **Module 1b real-time SPCS serving**); if it upgrades, restart the session and re-run.

> **Why a compute pool?** Container Runtime notebooks execute on Snowpark Container Services (SPCS), not on a virtual warehouse. The warehouse is used only for SQL pushdown/queries. If you don't have `CREATE COMPUTE POOL`, ask an `ACCOUNTADMIN` to create the pool and grant `USAGE` on it to your role.

> **Cleanup:** `DROP COMPUTE POOL CLIK_NOTEBOOK_POOL;` (or let `AUTO_SUSPEND` idle it) when the workshop ends.

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
Cell 8: register the best model as **`CLIK_PD_MODEL` version `V2_SNOWPARK_ML`** (default) with metrics. The model is trained on **one-hot-encoded features** (Snowpark ML), so inference expects the **60 encoded feature columns** (see the `SUBJECT_FEATURES_ENCODED` view below), not raw columns.

### Step 1.8 — Test inference from the registry
Cell 9: call `mv.run(..., function_name="predict_proba")` on 10 rows.

**Scaling to 1–5M rows / 1,000–2,000 features:** increase `SAMPLE_ROWS`, use a larger warehouse or a GPU compute pool, and consider `snowflake.ml.modeling` distributed estimators.

---

# Module 1b — Model Deployment

## Batch scoring (Warehouse)
Run **`04_model_deployment/04a_batch_scoring.sql`**:
- Creates the **`SUBJECT_FEATURES_ENCODED`** view (one-hot encoding of GENDER/EMPLOYMENT_TYPE/EDUCATION/REGION_CODE + derived `DTI_RATIO`) — the 60 model-ready features.
- Calls the registered model from SQL: `CLIK_PD_MODEL!PREDICT_PROBA(...)` and reads the `PREDICT_PROBA_1` object key (= probability of default).
- Writes results into `SCORE_RESULTS` with credit score (300–850) and decision (APPROVE / REVIEW / REJECT).

## Feature lookup with Hybrid Tables / Unistore (Step 3 of the architecture)
Run **`04_model_deployment/04c_hybrid_table_feature_lookup.sql`** to demo the **Precalculated Feature Table** pattern:
- Creates a **HYBRID TABLE** `SUBJECT_FEATURES_HT` (PK `SUBJECT_ID` + secondary index) — optimized for low-latency **point lookup by primary key** and high concurrency.
- Compares point lookup vs a standard table: hybrid scans **0 bytes** (row-store/index seek) while a standard table scans ~80–90 MB per lookup.
- `04_model_deployment/04c_hybrid_table_benchmark.py` measures client latency, TPS, and server-side `bytes_scanned`.

For real-time serving, the encoded features are stored in the hybrid table **`SUBJECT_FEATURES_ENCODED_HT`** (PK `SUBJECT_ID` + 60 encoded features) so the orchestration layer does a fast point lookup before calling the model.

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
mv = reg.get_model("CLIK_PD_MODEL").default   # version V2_SNOWPARK_ML
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

### Step 1b.4 — Call the REST API (from your laptop)
Set env vars then run **`04_model_deployment/04b_call_realtime.py`** (looks up 60 encoded features from `SUBJECT_FEATURES_ENCODED`, POSTs to the endpoint, reads `PREDICT_PROBA_1`):
```bash
export SNOWFLAKE_CONNECTION_NAME=<conn>
export CLIK_INGRESS_URL="<ingress_url>"
export CLIK_PAT="<YOUR_PAT>"
python 04b_call_realtime.py SUBJ000000020 SUBJ000000044
```
- **`04b_call_realtime_hybrid.py`** — same, but feature lookup is a **point lookup to the Hybrid Table** `SUBJECT_FEATURES_ENCODED_HT` (production pattern).

**Key payload rules (verified):**
- `dataframe_split` **must include the `index` key** → use `df.to_json(orient="split")` (NOT `index=False`, which returns HTTP 400 "missing required fields").
- Output shape is `{"data": [[<idx>, {..., "PREDICT_PROBA_1": <PD>}]]}`.
- Auth/URL failures return **HTTP 404** by design.

### Step 1b.5 — Call the REST API from INSIDE a Snowflake Notebook (HOL showcase, no PAT)
Run the REST call **from inside** a Snowflake Notebook (Container Runtime) using the **OAuth session token** the container already has — **no PAT, no External Access Integration**. This is the robust HOL path (PATs expire; the session token is auto-managed).

1. Open one of the showcase notebooks in Snowsight (Container Runtime):
   - **`04_model_deployment/04b_realtime_hybrid_rest.ipynb`** — feature lookup via **Hybrid Table point lookup** (`SUBJECT_FEATURES_ENCODED_HT`).
   - **`04_model_deployment/04b_realtime_view_rest.ipynb`** — feature lookup via **View/standard table** (`SUBJECT_FEATURES_ENCODED`) for comparison.
2. Run the cells. **Cell 1** reads the token and calls the **internal** service endpoint:
   ```python
   with open("/snowflake/session/token") as f:
       SF_TOKEN = f.read()
   dns  = session.sql("DESCRIBE SERVICE CLIK_WORKSHOP2.PUBLIC.CLIK_PD_SERVICE").collect()[0]["dns_name"]
   port = session.sql("SHOW ENDPOINTS IN SERVICE CLIK_WORKSHOP2.PUBLIC.CLIK_PD_SERVICE").collect()[0]["port"]
   ENDPOINT_URL = f"http://{dns}:{port}/predict-proba"
   HEADERS = {"Authorization": f'Snowflake Token="{SF_TOKEN}"', "Content-Type": "application/json"}
   ```
3. Flow per cell: **feature lookup → REST call (`requests`) → decision**.

> **Keep the service up:** the scoring compute pool auto-suspends when idle, which drops the service (calls return 503 / transient errors). Before the demo, resume and wait until READY:
> ```sql
> ALTER COMPUTE POOL CLIK_SCORING_POOL RESUME;
> SELECT SYSTEM$GET_SERVICE_STATUS('CLIK_WORKSHOP2.PUBLIC.CLIK_PD_SERVICE');  -- wait for READY
> ```
> For a long HOL, raise the idle timeout: `ALTER COMPUTE POOL CLIK_SCORING_POOL SET AUTO_SUSPEND_SECS = 7200;`

> **Calling from OUTSIDE Snowflake (laptop):** use `04b_call_realtime.py` / `04b_call_realtime_hybrid.py` with a PAT (env `CLIK_PAT`) against the public ingress URL — see Step 1b.4.

> **No-REST alternative:** **`04b_call_realtime_notebook.py`** calls the model with the internal SQL service function `CLIK_PD_SERVICE!PREDICT_PROBA(...)` — no token/URL needed.

---

# Module 2 — Dashboard: We Write the Code (45 min)

We build the dashboard with **Streamlit in Snowflake in Workspaces** (runs on a **compute pool / container runtime**). In this model, Python dependencies are declared in **`pyproject.toml`**, not `environment.yml`.

1. In Snowsight open a **Workspace** → **+ Add new » Streamlit app**. Snowflake creates starter files: `streamlit_app.py`, `pyproject.toml`, `snowflake.yml`, `.streamlit/config.toml`.
2. Paste the code from **`05_streamlit_dashboard/clik_dashboard.py`** into **`streamlit_app.py`**.
3. **Add package dependencies** — open **`pyproject.toml`** and add `plotly` (plus pandas/numpy) to the `[project].dependencies` array. Use **`05_streamlit_dashboard/pyproject.toml`** as reference:
   ```toml
   [project]
   dependencies = [
       "streamlit",
       "snowflake-snowpark-python",
       "plotly",
       "pandas",
       "numpy",
   ]
   ```
   > **This fixes `ModuleNotFoundError: No module named 'plotly'`.** Copying only `streamlit_app.py` is not enough — the container installs packages from `pyproject.toml`. After editing it, **rerun** the app (the compute pool reinstalls dependencies).
4. Press **Run** (Cmd/Ctrl+Enter) to preview the development app. When ready, click **Deploy** and set database `CLIK_WORKSHOP2`, schema `PUBLIC`, a compute pool, and query warehouse `GEN2_SMALL`.
5. The dashboard has 5 tabs covering every required component:
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
├── 04_model_deployment/      04a_batch_scoring.sql, 04b_realtime_spcs.sql, 04b_deploy_service.py,
│                             04b_call_realtime.py, 04b_call_realtime_hybrid.py,
│                             04b_call_realtime_notebook.py, 04b_call_realtime_notebook_rest.py,
│                             04b_notebook_rest_setup.sql, 04b_realtime_hybrid_rest.ipynb,
│                             04c_hybrid_table_feature_lookup.sql, 04c_hybrid_table_benchmark.py
├── 05_streamlit_dashboard/   clik_dashboard.py, pyproject.toml, environment.yml
├── 06_coco_prompting/        prompting_guide.md
├── 07_cortex_agent/          01_semantic_view.sql, 02_create_agent.sql, README.md
└── README.md                 (this file)
```

## Troubleshooting
- **Service stuck in PENDING** → check `SHOW SERVICE CONTAINERS IN SERVICE CLIK_PD_SERVICE;` and compute pool status.
- **404 on REST call** → wrong PAT, expired token, or wrong ingress URL (auth errors surface as 404).
- **`gpu_requests` error** → sklearn/xgb/lgbm are CPU models; keep `gpu_requests=None`.
- **Model version already exists** → bump `version_name` (e.g., `V2`) in the notebook.
