# Module 8 — Build an AI BI Dashboard in Snowflake Cowork (Dashboards 2.0)

> **PRIVATE PREVIEW.** "Dashboards in Snowflake Cowork" (a.k.a. Dashboards 2.0 / Artifacts 2.0) is available to selected accounts. Syntax/behavior may change before GA. Confirm enrollment with your account team.
>
> Docs: https://docs.snowflake.com/en/LIMITEDACCESS/cowork-dashboards

This module builds a full **credit-risk dashboard** on the CLIK data using every practical chart type, driven **AI-first** with Cortex Code (CoCo) in Snowsight Workspaces, then deployed to **Cowork** for conversational consumption.

---

## What you'll build

A single `.dash` dashboard with:
- **4 scorecards** (Total Apps, Approval Rate, Avg Credit Score, Default Rate)
- **Time series** (line; stacked area; area normalized; line + reference line)
- **Category comparison** (bar vertical/horizontal/stacked/normalized)
- **Part-to-whole** (donut, pie)
- **Heatmaps** (default-rate matrix; volume matrix)
- **Table** (lender performance)
- **Advanced via CoCo** (bubble/scatter, trellis small-multiples, funnel/waterfall)
- **Markdown** header + **5 dashboard filters**

All tiles read from the datamart `MART_APPLICATIONS`.

---

## Step 0 — Prerequisites

- Account enrolled in the Dashboards-in-Cowork private preview; **Cowork** enabled.
- Role with USAGE on a **compute pool** + a default **warehouse** (Workspaces run on container runtime).
- To deploy: `MANAGE ARTIFACT PUBLICATION` (granted to `PUBLIC` by default) + USAGE/CREATE on the target DB/schema.

---

## Step 1 — Build the datamart (baseline)

Run **`08_aibidashboard/01_datamart.sql`**. It creates:
- **`MART_APPLICATIONS`** — enriched fact **view** (1 row per application) joining `LOAN_APPLICATIONS` + `DIM_REGION/PRODUCT/LENDER` + `SCORE_RESULTS` + `SUBJECT_FEATURES`. Adds `APP_MONTH/WEEK/YEAR`, `IS_APPROVED`, `SCORE_BAND`, `RISK_SEGMENT`.
- **`MART_APP_MONTHLY`** — pre-aggregated **table** (month × dimensions) for lightweight tiles and fast filter dropdowns.

Validate:
```sql
SELECT COUNT(*) FROM CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS;   -- 50,000
SELECT COUNT(*) FROM CLIK_WORKSHOP2.PUBLIC.MART_APP_MONTHLY;    -- ~44,000
```

> **Why a datamart?** Tiles run **caller's rights** on each viewer's warehouse. A clean, denormalized mart (and a pre-aggregate) keeps tile SQL simple and filter dropdowns fast. Grant `SELECT` on these objects to the roles you will deploy to.

---

## Step 2 — Create the dashboard in a Workspace

1. Snowsight → **Workspaces** → open (or create) a workspace.
2. **Create > Dashboard** (or ask CoCo: *"/ai-bi-dashboard build a CLIK credit-risk dashboard from MART_APPLICATIONS"*). A `.dash` file is created.
3. Set the tile query context to `CLIK_WORKSHOP2.PUBLIC` and warehouse `GEN2_SMALL`.

**AI-first kickoff prompt (paste to CoCo):**
```
Build a credit-risk dashboard from CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS:
- a top row of 4 scorecards: total applications, approval rate %, avg credit score, default rate %
- a monthly application volume line chart
- a stacked area of monthly volume by DECISION
- a bar chart of applications by ISLAND_GROUP
- a donut of application share by CHANNEL
- a heatmap of default rate by ISLAND_GROUP x PRODUCT_CLASS
- a lender performance table
Add dashboard filters for date range (APP_DATE), ISLAND_GROUP, PRODUCT_CLASS, CHANNEL, RISK_SEGMENT.
```
CoCo generates the tiles + SQL + layout. Then iterate per Step 4.

---

## Step 3 — Add the filters (once per dashboard)

In the **Filters** panel define these 5 filters, then use the **Copy filter code** button to paste each `{{ filter('name') }}` into tile SQL.

| Filter name | Bound column | Type | UI mode | Value source |
|-------------|--------------|------|---------|--------------|
| `date_range` | `APP_DATE` | timestamp | date range / relative | — |
| `island_group` | `ISLAND_GROUP` | string | multi-select | column |
| `product_class` | `PRODUCT_CLASS` | string | multi-select | column |
| `channel` | `CHANNEL` | string | multi-select | column |
| `risk_segment` | `RISK_SEGMENT` | string | multi-select | static: `Low, Medium, High` |

**Standard WHERE block** to paste into every filterable tile:
```sql
WHERE {{ filter('date_range') }}
  AND {{ filter('island_group') }}
  AND {{ filter('product_class') }}
  AND {{ filter('channel') }}
  AND {{ filter('risk_segment') }}
```
Notes:
- A tile auto-connects to a filter the moment its SQL contains the matching placeholder.
- No selection = matches everything (never removes rows). Values are bound as parameters (injection-safe).
- Filter names are **case-sensitive** and must match the definition exactly.

---

## Step 4 — Add tiles (all chart types)

Full SQL for every tile is in **`08_aibidashboard/02_tile_queries.sql`**. Add tiles on the **12-column grid** (chart/table min 3×2; markdown min 1 row). Suggested layout:

| Row | Tiles (chart type) |
|-----|--------------------|
| 1 | Total Apps · Approval Rate · Avg Score · Default Rate — **Scorecard** ×4 |
| 2 | Monthly volume **Line** · Monthly by decision **Area (stacked)** · Approval trend **Line + reference line** |
| 3 | By Island **Bar** · Top regions **Bar (horizontal)** · Product×Decision **Bar (stacked)** · Decision mix by channel **Bar (normalized)** |
| 4 | Channel share **Donut** · Risk mix **Pie** |
| 5 | Default rate Island×Class **Heatmap** · Volume ScoreBand×Channel **Heatmap** |
| 6 | Lender performance **Table** |
| 7 | Risk vs approval **Bubble** · Monthly by island **Trellis** · Decision **Funnel/Waterfall** |
| 0 | Title **Markdown** (span full width at top) |

**Point-and-click chart types** (editor panel — no code):
- **Scorecard** — return one number (queries 1a–1d). Add a delta by comparing to a prior period.
- **Line** — X=`APP_MONTH`, Y=`applications` (2a).
- **Area stacked / normalized** — 2b; set `stack = zero` (stacked) or `normalize` (100%).
- **Bar** vertical (3a), **horizontal** (3b, swap axes), **stacked** (3c), **normalized** (3d, `stack = normalize`).
- **Donut / Pie** — 4a / 4b.
- **Heatmap** — X=`PRODUCT_CLASS`, Y=`ISLAND_GROUP`, color=`default_rate_pct` (5a); or ScoreBand×Channel (5b).
- **Table** — 6a; sorting/resize/pagination built in.

**Advanced chart types via CoCo** (it edits the Vega-Lite spec — often faster than manual):
- **Bubble/scatter** (7a): *"make this a bubble chart: X=avg_pd, Y=approval_rate_pct, size=applications, color=ISLAND_GROUP; add a target rule line at 85 on Y."*
- **Trellis / small multiples** (7b): *"facet this line chart into small multiples by ISLAND_GROUP."*
- **Funnel / waterfall** (7c): *"render as a horizontal funnel ordered APPROVE, REVIEW, REJECT."*
- **Reference line** on 2c: *"add a horizontal rule at 85 labeled 'target'."*
- **Brand palette:** *"switch the color scale to the Snowflake brand palette."*

> **Not supported in preview:** geospatial **map** chart types.

**Markdown tile** (row 0), example content:
```markdown
# CLIK Credit Risk Dashboard
Source: `MART_APPLICATIONS` · Model: `CLIK_PD_MODEL (V2_SNOWPARK_ML)`
Use the filters above to focus the analysis, then ask any tile a follow-up in Cowork.
```

---

## Step 5 — Preview & iterate

- Press **Run** (Cmd/Ctrl+Enter) to preview the private development app.
- Iterate conversationally: *"change the trend to weekly", "sort the bar descending", "add data labels", "make the scorecards one row".*
- Verify a filter: pick `ISLAND_GROUP = Jawa` and confirm every connected tile updates and totals re-aggregate correctly.

---

## Step 6 — Deploy to Cowork (consumption)

1. In the project pane, click **Deploy**.
2. Set **Location** (DB/schema), **Execution** (compute pool + query warehouse `GEN2_SMALL`), optional **Network** (EAI), and **Sharing** = the role(s) that should see it.
3. **Deploy.** Holders of those roles see it in Cowork under **Shared with me** immediately.

Governance:
```sql
-- Curate who can deploy (default is PUBLIC)
REVOKE MANAGE ARTIFACT PUBLICATION FROM ROLE PUBLIC;
GRANT  MANAGE ARTIFACT PUBLICATION TO ROLE CLIK_ANALYST;   -- example
-- Recipients also need SELECT on the mart (caller's rights):
GRANT SELECT ON VIEW  CLIK_WORKSHOP2.PUBLIC.MART_APPLICATIONS TO ROLE CLIK_VIEWER;
GRANT SELECT ON TABLE CLIK_WORKSHOP2.PUBLIC.MART_APP_MONTHLY  TO ROLE CLIK_VIEWER;
```
> **Caller's rights:** each viewer's tiles run with *their* privileges. No SELECT on the mart ⇒ empty tiles. Update flow: **Publish changes** (workspace collaborators) vs **Deploy** (pushes new version to all Cowork consumers).

---

## Step 7 — Consume conversationally in Cowork

Open the dashboard on the Cowork **Artifacts** page; a chat bar sits at the bottom. Ask follow-ups on any tile:
- *"Why did the approval rate drop in Q1 2026?"*
- *"Which island group has the highest default rate for unsecured products?"*
- *"Break down REJECT applications by channel."*

Notes: follow-ups run with the viewer's permissions; conversational filters stay in that chat thread and don't change the dashboard for others. (Adding/removing tiles happens in Workspaces, not Cowork.)

---

## Migrating from Legacy Snowsight Dashboards
- Replace `:filter_name` with `{{ filter('name') }}` and add a per-dashboard filter definition (no account-global filters).
- UBAC → RBAC (deploy to roles). Owner's-rights cache → caller's rights (grant SELECT on the mart).
- Rebuild each chart as a Vega-Lite tile; no automated migration tool in preview.

## Files in this module
```
08_aibidashboard/
├── 01_datamart.sql        -- MART_APPLICATIONS (view) + MART_APP_MONTHLY (table)
├── 02_tile_queries.sql    -- SQL for every tile, with {{ filter() }} placeholders
└── 02_build_guide.md      -- this guide
```
