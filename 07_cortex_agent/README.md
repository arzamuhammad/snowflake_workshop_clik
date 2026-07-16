# Modul 07 — Cortex Agent: Talk to Your Data (via Snowflake Cowork)

## Overview
Modul ini membangun chatbot AI analytics menggunakan:
1. **Cortex Analyst** (semantic view) — SQL generation dari natural language
2. **Cortex Agent** — orchestrator yang menggabungkan tools
3. **Snowflake Cowork** — UI chat interface bawaan Snowflake

## Langkah-langkah

### Step 1: Buat Semantic View
Jalankan `01_semantic_view.sql` untuk membuat semantic view `CLIK_CREDIT_ANALYTICS`.
Ini mendefinisikan dimensi, measures, dan time dimensions atas tabel kita.

### Step 2: Buat Cortex Agent (via Snowsight UI — Semantic Studio)
1. Buka **Snowsight** → **AI & ML** → **Cortex AI** → **Agents**
2. Klik **+ Create Agent**
3. Konfigurasi:
   - **Name:** `CLIK_ANALYTICS_AGENT`
   - **Database/Schema:** `CLIK_WORKSHOP2.PUBLIC`
   - **Instructions:**
     ```
     You are a credit bureau analytics assistant for CLIK (PT CRIF Lembaga Informasi Keuangan).
     You help users analyze loan application data, credit risk metrics, and portfolio performance.
     Always provide clear explanations with the data. Use Indonesian when user writes in Indonesian.
     When showing monetary values, use IDR format (Rp).
     ```
   - **Tools:**
     - Add **Analyst tool** → select semantic view `CLIK_WORKSHOP2.PUBLIC.CLIK_CREDIT_ANALYTICS`

4. **Test** agent di panel kanan dengan pertanyaan:
   - "Berapa total aplikasi per bulan di 2025?"
   - "Tunjukkan approval rate per region"
   - "What is the default rate by KOL status?"
   - "Compare average loan amount across product types"
   - "Trend applications by channel over time"

### Step 3: Akses via Snowflake Cowork
Setelah agent dibuat, akses via **Snowflake Cowork** (chat icon di Snowsight):
1. Klik icon chat (Cowork) di sidebar kiri
2. Pilih agent `CLIK_ANALYTICS_AGENT`
3. Mulai chat — agent akan generate SQL dari pertanyaan Anda

### Step 4 (Opsional): Buat Agent via SQL
Alternatif programmatic di `02_create_agent.sql`.

## Contoh Pertanyaan untuk Demo

### Bahasa Indonesia:
- "Berapa total aplikasi kredit yang masuk bulan lalu?"
- "Tunjukkan approval rate per produk dan per channel dalam bentuk cross-tab"
- "Region mana yang paling banyak reject?"
- "Berapa rata-rata probability of default untuk nasabah dengan KOL status 3?"
- "Tren bulanan jumlah aplikasi BNPL vs KTA"

### English:
- "Show me the monthly trend of applications in 2025"
- "What is the average income of defaulted vs non-defaulted subjects?"
- "Compare credit utilization across regions"
- "Top 5 lenders by application volume"
- "Distribution of default rate by age group"
