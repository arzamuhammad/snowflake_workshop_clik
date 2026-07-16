# CLIK Workshop 2 — End-to-End ML + Dashboard + AI Agent
## PT CRIF Lembaga Informasi Keuangan (CLIK) | Snowflake

**Durasi:** 10:00 – 15:00 (5 jam)  
**Use Case:** Credit Default Prediction (Probability of Default)  
**Database:** `CLIK_WORKSHOP2.PUBLIC` | **Warehouse:** `GEN2_SMALL`

---

## Struktur Workshop

| # | Modul | Folder | Durasi |
|---|-------|--------|--------|
| 0 | Setup (DB, stage, data) | `00_setup/` + `02_data_load/` | 30 min |
| 1 | End-to-End ML | `03_ml_notebook/` + `04_model_deployment/` | 120 min |
| 2 | Dashboard (Process 1: code) | `05_streamlit_dashboard/` | 45 min |
| 3 | Dashboard (Process 2: CoCo AI prompting) | `06_coco_prompting/` | 30 min |
| 4 | AI Agent / Talk to Your Data | `07_cortex_agent/` | 45 min |

---

## Quick Start

### 1. Setup Environment
```sql
-- Jalankan 00_setup/00_setup.sql
-- Lalu 02_data_load/01_create_tables.sql
-- Lalu 02_data_load/02_generate_subject_features.sql (1jt baris, ~16 detik)
```

### 2. Load CSV (via Git → Stage → Table)
```sql
-- Ikuti 02_data_load/03_load_from_git.sql
-- ATAU manual PUT + COPY INTO (jika belum setup Git integration)
```

### 3. ML Notebook
Buka `03_ml_notebook/01_end_to_end_ml_pd.ipynb` di Snowflake Notebooks (Container Runtime).

### 4. Model Deployment
- **Batch:** `04_model_deployment/04a_batch_scoring.sql`
- **Real-time SPCS:** `04_model_deployment/04b_realtime_spcs.sql` + `04b_call_realtime.py`

### 5. Dashboard
Copy `05_streamlit_dashboard/clik_dashboard.py` ke Streamlit in Snowflake. Env: `environment.yml`.

### 6. CoCo Prompting
Ikuti `06_coco_prompting/prompting_guide.md` — 7 langkah progressif membangun dashboard via AI.

### 7. Cortex Agent
```sql
-- 07_cortex_agent/01_semantic_view.sql (buat semantic view)
-- 07_cortex_agent/02_create_agent.sql (buat agent)
-- Atau via UI: Snowsight → AI & ML → Agents → Create
```

---

## Data Summary

| Table | Rows | Description |
|-------|------|-------------|
| `SUBJECT_FEATURES` | 1,000,000 | 198 kolom fitur biro kredit + default_flag (8.07%) |
| `LOAN_APPLICATIONS` | 50,000 | Aplikasi kredit 18 bulan (Jan 2025 – Jun 2026) |
| `DIM_REGION` | 18 | Provinsi Indonesia |
| `DIM_PRODUCT` | 7 | Jenis produk kredit |
| `DIM_LENDER` | 12 | Bank & fintech members |

---

## Snowflake Features Demonstrated

- Snowflake Notebooks (Container Runtime) — ML training
- Model Registry — log_model, versioning
- SPCS Model Serving — real-time REST inference
- Streamlit in Snowflake — interactive dashboard
- Cortex Code (CoCo) — AI-assisted development
- Cortex Analyst (Semantic View) — natural language to SQL
- Cortex Agent — AI chatbot / talk to your data
- Snowflake Cowork — conversational analytics UI
- Git Integration + Workspaces — source control & collaboration
- GENERATOR + RANDOM — synthetic data at scale

---

## Git Repository

**Private:** https://github.com/arzamuhammad/snowflake_workshop_clik

Untuk Snowflake Git Integration, ganti `<GITHUB_USER>` dan `<GITHUB_PAT>` di `03_load_from_git.sql`.

---

## Prasyarat Peserta

- Akun Snowflake (non-trial recommended untuk SPCS)
- Role ACCOUNTADMIN atau role dengan CREATE DATABASE
- Warehouse SMALL atau lebih besar
- Browser modern (untuk Snowsight, Streamlit, Cowork)
