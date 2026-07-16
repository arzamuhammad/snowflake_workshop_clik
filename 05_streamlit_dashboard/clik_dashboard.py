import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="CLIK Credit Bureau Dashboard", layout="wide")

session = get_active_session()

st.markdown("""
<style>
.kpi-card {border-radius:12px;padding:20px 24px;color:white;text-align:center;}
.kpi-val {font-size:2.2rem;font-weight:700;margin:0;}
.kpi-lbl {font-size:0.85rem;opacity:0.85;margin-top:4px;}
</style>
""", unsafe_allow_html=True)

@st.cache_data(ttl=300)
def load_applications():
    return session.table("CLIK_WORKSHOP2.PUBLIC.LOAN_APPLICATIONS").to_pandas()

@st.cache_data(ttl=300)
def load_scores():
    return session.sql("""
        SELECT s.SUBJECT_ID, s.DEFAULT_FLAG, s.AGE, s.MONTHLY_INCOME,
               s.CREDIT_UTILIZATION, s.KOL_STATUS, s.REGION_CODE, s.GENDER,
               s.PD_TRUE_PROB
        FROM CLIK_WORKSHOP2.PUBLIC.SUBJECT_FEATURES s SAMPLE (50000 ROWS)
    """).to_pandas()

apps = load_applications()
scores = load_scores()
apps["APP_DATE"] = pd.to_datetime(apps["APP_DATE"])

tabs = st.tabs(["Overview", "Time Series", "Heatmap & Cross-Tab", "Risk Analysis", "Portfolio"])

# ═══════════════════════════════════════════════════════════
# TAB 1 — OVERVIEW (KPI Cards + Funnel + Donut)
# ═══════════════════════════════════════════════════════════
with tabs[0]:
    st.subheader("Overview KPI")
    total_apps = len(apps)
    approval_rate = (apps["DECISION"] == "APPROVE").mean()
    avg_amount = apps["REQUESTED_AMOUNT"].mean()
    default_rate = scores["DEFAULT_FLAG"].mean()
    avg_income = scores["MONTHLY_INCOME"].mean()
    avg_util = scores["CREDIT_UTILIZATION"].mean()

    cols = st.columns(6)
    kpis = [
        (f"{total_apps:,.0f}", "Total Applications", "#6C63FF"),
        (f"{approval_rate:.1%}", "Approval Rate", "#00C9A7"),
        (f"Rp {avg_amount/1e6:.0f}M", "Avg Loan Amount", "#FF6B6B"),
        (f"{default_rate:.1%}", "Default Rate", "#FFA62B"),
        (f"Rp {avg_income/1e6:.1f}M", "Avg Income", "#845EC2"),
        (f"{avg_util:.0%}", "Avg Utilization", "#4B8BBE"),
    ]
    for col, (val, lbl, color) in zip(cols, kpis):
        col.markdown(f'<div class="kpi-card" style="background:linear-gradient(135deg,{color},{color}dd)"><p class="kpi-val">{val}</p><p class="kpi-lbl">{lbl}</p></div>', unsafe_allow_html=True)

    st.markdown("---")
    c1, c2 = st.columns(2)

    with c1:
        st.markdown("##### Application Funnel")
        funnel_data = apps["DECISION"].value_counts().reindex(["APPROVE","REVIEW","REJECT"]).fillna(0)
        fig = go.Figure(go.Funnel(
            y=funnel_data.index, x=funnel_data.values,
            marker=dict(color=["#00C9A7","#FFA62B","#FF6B6B"]),
            textinfo="value+percent initial"))
        fig.update_layout(height=300, margin=dict(l=20,r=20,t=20,b=20))
        st.plotly_chart(fig, use_container_width=True)

    with c2:
        st.markdown("##### Channel Distribution")
        ch = apps["CHANNEL"].value_counts()
        fig = px.pie(values=ch.values, names=ch.index, hole=0.5,
                     color_discrete_sequence=px.colors.qualitative.Set2)
        fig.update_layout(height=300, margin=dict(l=20,r=20,t=20,b=20))
        st.plotly_chart(fig, use_container_width=True)

# ═══════════════════════════════════════════════════════════
# TAB 2 — TIME SERIES
# ═══════════════════════════════════════════════════════════
with tabs[1]:
    st.subheader("Application Trends")
    freq = st.radio("Frequency", ["Monthly", "Weekly"], horizontal=True)
    rule = "MS" if freq == "Monthly" else "W"
    ts = apps.set_index("APP_DATE").resample(rule).agg(
        total=("APPLICATION_ID","count"),
        approved=("DECISION", lambda x: (x=="APPROVE").sum()),
        avg_amount=("REQUESTED_AMOUNT","mean")
    ).reset_index()

    fig = go.Figure()
    fig.add_trace(go.Scatter(x=ts["APP_DATE"], y=ts["total"], name="Total Apps",
                             fill="tozeroy", fillcolor="rgba(108,99,255,0.15)",
                             line=dict(color="#6C63FF", width=2)))
    fig.add_trace(go.Scatter(x=ts["APP_DATE"], y=ts["approved"], name="Approved",
                             fill="tozeroy", fillcolor="rgba(0,201,167,0.12)",
                             line=dict(color="#00C9A7", width=2)))
    fig.update_layout(height=350, template="plotly_white",
                      legend=dict(orientation="h", y=1.05), margin=dict(t=30))
    st.plotly_chart(fig, use_container_width=True)

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("##### Avg Loan Amount Trend")
        fig2 = px.line(ts, x="APP_DATE", y="avg_amount", color_discrete_sequence=["#845EC2"])
        fig2.update_layout(height=250, template="plotly_white")
        st.plotly_chart(fig2, use_container_width=True)
    with c2:
        st.markdown("##### Approval Rate Trend")
        ts["appr_rate"] = ts["approved"] / ts["total"]
        fig3 = px.bar(ts, x="APP_DATE", y="appr_rate", color_discrete_sequence=["#00C9A7"])
        fig3.update_layout(height=250, template="plotly_white", yaxis_tickformat=".0%")
        st.plotly_chart(fig3, use_container_width=True)

# ═══════════════════════════════════════════════════════════
# TAB 3 — HEATMAP & CROSS-TAB
# ═══════════════════════════════════════════════════════════
with tabs[2]:
    st.subheader("Cross-Tabulation & Heatmap")
    c1, c2 = st.columns(2)
    row_dim = c1.selectbox("Rows", ["PRODUCT_CODE","REGION_CODE","CHANNEL","LENDER_CODE"], index=0)
    col_dim = c2.selectbox("Columns", ["DECISION","CHANNEL","PRODUCT_CODE"], index=0)

    ct = pd.crosstab(apps[row_dim], apps[col_dim], margins=True)
    st.dataframe(ct.style.background_gradient(cmap="YlOrRd", axis=1), use_container_width=True)

    st.markdown("##### Heatmap: Approval Rate by Region x Product")
    pivot = apps.pivot_table(index="REGION_CODE", columns="PRODUCT_CODE",
                             values="DECISION", aggfunc=lambda x: (x=="APPROVE").mean())
    fig = px.imshow(pivot, color_continuous_scale="RdYlGn", aspect="auto",
                    labels=dict(color="Approval Rate"))
    fig.update_layout(height=450)
    st.plotly_chart(fig, use_container_width=True)

# ═══════════════════════════════════════════════════════════
# TAB 4 — RISK ANALYSIS
# ═══════════════════════════════════════════════════════════
with tabs[3]:
    st.subheader("Risk Analysis")
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("##### Default Rate by KOL Status")
        kol = scores.groupby("KOL_STATUS").agg(
            default_rate=("DEFAULT_FLAG","mean"), count=("SUBJECT_ID","count")).reset_index()
        fig = px.bar(kol, x="KOL_STATUS", y="default_rate", text="count",
                     color="default_rate", color_continuous_scale="Reds")
        fig.update_layout(height=300, yaxis_tickformat=".1%")
        st.plotly_chart(fig, use_container_width=True)
    with c2:
        st.markdown("##### PD Distribution")
        fig = px.histogram(scores, x="PD_TRUE_PROB", nbins=50, color="DEFAULT_FLAG",
                           color_discrete_map={0:"#00C9A7", 1:"#FF6B6B"}, barmode="overlay")
        fig.update_layout(height=300)
        st.plotly_chart(fig, use_container_width=True)

    st.markdown("##### Risk Heatmap: Age Group x Utilization Band")
    scores["AGE_GROUP"] = pd.cut(scores["AGE"], bins=[20,30,40,50,60,70], labels=["21-30","31-40","41-50","51-60","61+"])
    scores["UTIL_BAND"] = pd.cut(scores["CREDIT_UTILIZATION"], bins=[0,0.3,0.6,0.9,1.2], labels=["Low","Med","High","Over"])
    hm = scores.pivot_table(index="AGE_GROUP", columns="UTIL_BAND", values="DEFAULT_FLAG", aggfunc="mean")
    fig = px.imshow(hm, color_continuous_scale="YlOrRd", aspect="auto",
                    labels=dict(color="Default Rate"))
    fig.update_layout(height=350)
    st.plotly_chart(fig, use_container_width=True)

# ═══════════════════════════════════════════════════════════
# TAB 5 — PORTFOLIO
# ═══════════════════════════════════════════════════════════
with tabs[4]:
    st.subheader("Portfolio Overview")
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("##### Top Regions by Volume")
        reg = apps.groupby("REGION_CODE").agg(vol=("APPLICATION_ID","count"),
                                              avg_amt=("REQUESTED_AMOUNT","mean")).reset_index().sort_values("vol",ascending=False).head(10)
        fig = px.bar(reg, x="REGION_CODE", y="vol", color="avg_amt",
                     color_continuous_scale="Viridis")
        fig.update_layout(height=300)
        st.plotly_chart(fig, use_container_width=True)
    with c2:
        st.markdown("##### Product Mix (Amount)")
        prod = apps.groupby("PRODUCT_CODE")["REQUESTED_AMOUNT"].sum().reset_index()
        fig = px.pie(prod, values="REQUESTED_AMOUNT", names="PRODUCT_CODE", hole=0.4,
                     color_discrete_sequence=px.colors.qualitative.Pastel)
        fig.update_layout(height=300)
        st.plotly_chart(fig, use_container_width=True)

    st.markdown("##### Monthly Volume by Product (Stacked Area)")
    monthly_prod = apps.set_index("APP_DATE").groupby([pd.Grouper(freq="MS"),"PRODUCT_CODE"]).size().reset_index(name="count")
    fig = px.area(monthly_prod, x="APP_DATE", y="count", color="PRODUCT_CODE",
                  color_discrete_sequence=px.colors.qualitative.Set2)
    fig.update_layout(height=350, template="plotly_white")
    st.plotly_chart(fig, use_container_width=True)
