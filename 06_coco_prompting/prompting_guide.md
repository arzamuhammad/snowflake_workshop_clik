# CLIK Workshop 2 — Panduan Prompting Cortex Code (CoCo)
## Membangun Streamlit Dashboard dengan AI

Panduan ini mengajarkan bagaimana membangun dashboard Streamlit in Snowflake
**secara bertahap** menggunakan prompt ke Cortex Code (CoCo) di Workspaces.

> **Prasyarat:** Buka Workspaces → tambahkan file `.py` baru → buka Cortex Code panel.

---

## Langkah 1: Setup Dasar + KPI Cards

**Prompt:**
```
Buatkan Streamlit app yang connect ke Snowflake session, load data dari tabel
CLIK_WORKSHOP2.PUBLIC.LOAN_APPLICATIONS, lalu tampilkan 4 KPI cards berwarna
(Total Applications, Approval Rate, Avg Loan Amount, Default Rate) menggunakan
st.columns dan HTML styling dengan gradient background warna ungu, hijau, merah, orange.
Gunakan plotly untuk charts.
```

**Hasil yang diharapkan:** 4 KPI cards berwarna di baris atas.

---

## Langkah 2: Time Series Chart

**Prompt:**
```
Tambahkan tab "Time Series" yang menampilkan:
1. Area chart monthly trend total applications vs approved (dual line, fill area)
2. Line chart rata-rata loan amount per bulan
Gunakan plotly, warna ungu untuk total dan hijau untuk approved.
Tambahkan radio button untuk switch antara Monthly dan Weekly.
```

**Hasil:** Area chart interaktif dengan toggle frekuensi.

---

## Langkah 3: Heatmap

**Prompt:**
```
Tambahkan tab "Heatmap" yang berisi:
1. Heatmap approval rate by REGION_CODE (rows) x PRODUCT_CODE (columns)
   menggunakan px.imshow, color scale RdYlGn
2. Tambahkan juga heatmap risk: AGE_GROUP (21-30,31-40,41-50,51-60,61+)
   vs CREDIT_UTILIZATION band (Low <0.3, Med 0.3-0.6, High 0.6-0.9, Over >0.9)
   menunjukkan default rate dari tabel SUBJECT_FEATURES (sample 50000).
```

**Hasil:** 2 heatmap interaktif dengan gradasi warna.

---

## Langkah 4: Cross-Tabulation Table

**Prompt:**
```
Tambahkan cross-tabulation table interaktif:
- User bisa pilih row dimension (product, region, channel, lender)
  dan column dimension (decision, channel, product) via selectbox
- Tampilkan sebagai styled dataframe dengan background_gradient "YlOrRd"
- Tambahkan margins (total row/column)
```

**Hasil:** Tabel cross-tab dengan conditional formatting heatmap.

---

## Langkah 5: Interactive Filters

**Prompt:**
```
Tambahkan sidebar filters:
- Date range picker (min/max dari APP_DATE)
- Multiselect untuk REGION_CODE
- Multiselect untuk PRODUCT_CODE
- Multiselect untuk CHANNEL
Semua chart dan KPI harus ter-filter sesuai pilihan user.
```

**Hasil:** Sidebar dengan filters, semua visualisasi reaktif.

---

## Langkah 6: Donut/Pie Chart + Funnel

**Prompt:**
```
Di tab Overview, tambahkan:
1. Funnel chart (Application -> Review -> Approve) menggunakan go.Funnel
   dengan warna hijau, orange, merah
2. Donut chart channel distribution menggunakan px.pie dengan hole=0.5
Layout: 2 kolom sejajar di bawah KPI cards.
```

**Hasil:** Funnel + donut chart dalam layout 2 kolom.

---

## Langkah 7: Polish & Styling

**Prompt:**
```
Perbaiki styling dashboard:
- Gunakan st.set_page_config(layout="wide")
- Tambahkan CSS custom: border-radius pada cards, shadow subtle
- Gunakan template plotly_white untuk semua charts
- Pastikan semua chart responsive (use_container_width=True)
- Tambahkan judul "CLIK Credit Bureau Dashboard" di atas
```

**Hasil:** Dashboard polished, responsive, siap produksi.

---

## Tips Prompting yang Efektif

| Do | Don't |
|----|-------|
| Spesifik tentang data (nama tabel, kolom) | Biarkan AI menebak schema |
| Minta satu komponen per prompt | Minta semua sekaligus |
| Sebutkan library (plotly, px.imshow) | Asumsi AI tahu preferensi Anda |
| Berikan contoh warna/style | Terima default styling |
| Iterasi: perbaiki satu hal | Rewrite dari awal tiap kali |

---

## Bonus: Prompt untuk Chart Lainnya

**Stacked area (volume by product per bulan):**
```
Tambahkan stacked area chart monthly volume per PRODUCT_CODE
menggunakan px.area dengan color palette Set2.
```

**Bar chart with dual axis:**
```
Buat bar chart jumlah aplikasi per region (sumbu kiri)
dengan line overlay rata-rata amount (sumbu kanan) menggunakan go.Figure + secondary_y.
```

**Scatter plot risk:**
```
Buat scatter plot CREDIT_UTILIZATION (x) vs MONTHLY_INCOME (y),
warnai berdasarkan DEFAULT_FLAG, gunakan opacity rendah (0.3) karena banyak titik.
```
