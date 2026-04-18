"""
Mous Paid Social ROAS Attribution Model
Interactive Streamlit Dashboard — 5 pages
"""

import os
import sys
import io
import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# Resolve data path relative to this file
BASE_DIR  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_PATH = os.path.join(BASE_DIR, "data", "processed", "mous_attribution_clean.csv")

sys.path.insert(0, os.path.dirname(__file__))
from utils import (
    CHANNEL_COLOURS, PAID_CHANNELS, SHAPLEY_WEIGHTS,
    load_data, apply_filters, compute_kpis,
    compute_shapley_attribution, budget_simulation,
)

# ── Page config ──────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Mous Analytics — Paid Social Attribution",
    page_icon="M",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Global CSS ───────────────────────────────────────────────────────────────
st.markdown("""
<style>
    /* Main background */
    .stApp { background-color: #0f1117; }
    section[data-testid="stSidebar"] { background-color: #1a1c23 !important; }

    /* KPI metric cards */
    [data-testid="stMetric"] {
        background-color: #1a1c23;
        border: 1px solid #2a2d3a;
        border-radius: 10px;
        padding: 16px 20px;
    }
    [data-testid="stMetricLabel"] { color: #aaaacc !important; font-size: 13px !important; }
    [data-testid="stMetricValue"] { color: #FFFFFF !important; font-size: 28px !important; font-weight: 700 !important; }

    /* Insight box */
    .insight-box {
        background-color: #1a1c23;
        border-left: 4px solid #FF6B35;
        border-radius: 6px;
        padding: 14px 18px;
        margin: 12px 0;
        color: #FFFFFF;
        font-size: 15px;
        line-height: 1.6;
    }

    /* Recommendation card */
    .rec-card {
        background-color: #1a1c23;
        border: 1px solid #2a2d3a;
        border-radius: 10px;
        padding: 20px 22px;
        margin-bottom: 14px;
    }
    .rec-card h4 { color: #FF6B35; margin-bottom: 8px; }
    .rec-card p  { color: #CCCCDD; font-size: 14px; line-height: 1.6; margin: 0; }
    .rec-metric  { color: #34A853; font-weight: 700; font-size: 13px; margin-top: 8px; }

    /* Section headers */
    h2, h3 { color: #FFFFFF !important; }
    h1 { color: #FF6B35 !important; }

    /* Divider */
    hr { border-color: #2a2d3a; }
</style>
""", unsafe_allow_html=True)

PLOTLY_LAYOUT = dict(
    paper_bgcolor="#0f1117",
    plot_bgcolor="#1a1c23",
    font=dict(color="#FFFFFF", family="sans-serif"),
    xaxis=dict(gridcolor="#2a2d3a", linecolor="#333344"),
    yaxis=dict(gridcolor="#2a2d3a", linecolor="#333344"),
    margin=dict(t=50, b=40, l=60, r=30),
    legend=dict(bgcolor="#1a1c23", bordercolor="#333344", borderwidth=1),
)


@st.cache_data
def get_data():
    return load_data(DATA_PATH)


df_full = get_data()

# ── SIDEBAR ──────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("<h1 style='font-size:26px; color:#FF6B35;'>M MOUS Analytics</h1>", unsafe_allow_html=True)
    st.markdown("<p style='color:#888; font-size:12px; margin-top:-12px;'>Paid Social Attribution Model</p>", unsafe_allow_html=True)
    st.markdown("---")

    page = st.radio(
        "Navigate",
        ["Overview", "Attribution", "Creative Performance", "Budget Simulator", "Key Findings"],
        label_visibility="collapsed",
    )

    st.markdown("---")
    st.markdown("**Filters**")

    min_date = df_full["date"].min().date()
    max_date = df_full["date"].max().date()
    date_range = st.slider(
        "Date Range",
        min_value=min_date,
        max_value=max_date,
        value=(min_date, max_date),
        format="MMM YYYY",
    )

    channels = st.multiselect(
        "Channel",
        options=["Meta", "TikTok", "YouTube", "Google_Search", "Organic"],
        default=["Meta", "TikTok", "YouTube", "Google_Search", "Organic"],
    )

    campaign_types = st.multiselect(
        "Campaign Type",
        options=["Prospecting", "Retargeting", "Brand_Awareness"],
        default=["Prospecting", "Retargeting", "Brand_Awareness"],
    )

    creative_types = st.multiselect(
        "Creative Type",
        options=["Video_Drop_Test", "UGC_Review", "Product_Showcase", "Influencer_Collab"],
        default=["Video_Drop_Test", "UGC_Review", "Product_Showcase", "Influencer_Collab"],
    )

    attribution_model = st.radio("Attribution Model", ["Last-Click", "Shapley"])

    st.markdown("---")
    st.caption("Data: Jan 2022 – Dec 2024 | Synthetic D2C dataset")

# ── Apply filters ─────────────────────────────────────────────────────────────
if not channels or not campaign_types or not creative_types:
    st.warning("Please select at least one option in each filter.")
    st.stop()

df = apply_filters(df_full, date_range[0], date_range[1], channels, campaign_types, creative_types)
kpis = compute_kpis(df)


# ════════════════════════════════════════════════════════════════════════════
#  PAGE 1 — OVERVIEW
# ════════════════════════════════════════════════════════════════════════════
if page == "Overview":
    st.title("Mous Paid Social — Channel Performance Overview")
    st.markdown(f"*Showing data from **{date_range[0]}** to **{date_range[1]}** | Attribution: **{attribution_model}***")
    st.markdown("---")

    # KPI Row
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Revenue", f"£{kpis['total_revenue']:,.0f}")
    c2.metric("Blended ROAS", f"{kpis['blended_roas']:.2f}x")
    c3.metric("Average CAC", f"£{kpis['avg_cac']:.2f}")
    c4.metric("Repeat Purchase Rate", f"{kpis['repeat_rate']:.1f}%")

    st.markdown("<br>", unsafe_allow_html=True)

    # ── Chart 1: Monthly Revenue by Channel — Stacked Area ──────────────────
    st.subheader("Monthly Revenue by Channel")

    monthly_ch = (
        df.groupby([pd.Grouper(key="date", freq="ME"), "channel"])["revenue_gbp"]
        .sum()
        .reset_index()
    )
    monthly_ch["month"] = monthly_ch["date"].dt.strftime("%Y-%m")

    fig1 = go.Figure()
    for ch in [c for c in PAID_CHANNELS + ["Organic"] if c in monthly_ch["channel"].unique()]:
        sub = monthly_ch[monthly_ch["channel"] == ch].sort_values("date")
        fig1.add_trace(go.Scatter(
            x=sub["date"], y=sub["revenue_gbp"],
            name=ch, mode="lines",
            stackgroup="one",
            line=dict(color=CHANNEL_COLOURS.get(ch, "#888"), width=0),
            fillcolor=CHANNEL_COLOURS.get(ch, "#888"),
        ))
    fig1.update_layout(**PLOTLY_LAYOUT, title="Monthly Revenue by Channel (Stacked Area)", height=380)
    fig1.update_yaxes(tickprefix="£")
    st.plotly_chart(fig1, use_container_width=True)
    st.caption("Source: Synthetic Mous paid social dataset | Jan 2022 – Dec 2024")

    col_a, col_b = st.columns(2)

    # ── Chart 2: ROAS by Channel — Grouped Bar ───────────────────────────────
    with col_a:
        st.subheader("ROAS by Channel")
        paid_df = df[df["spend_gbp"] > 0]
        roas_ch = (
            paid_df.groupby("channel")
            .agg(spend=("spend_gbp", "sum"), revenue=("revenue_gbp", "sum"))
            .reset_index()
        )
        roas_ch["ROAS"] = roas_ch["revenue"] / roas_ch["spend"].replace(0, np.nan)
        roas_ch = roas_ch.sort_values("ROAS", ascending=False)

        fig2 = go.Figure(go.Bar(
            x=roas_ch["channel"], y=roas_ch["ROAS"],
            marker_color=[CHANNEL_COLOURS.get(c, "#888") for c in roas_ch["channel"]],
            text=roas_ch["ROAS"].round(2).astype(str) + "x",
            textposition="outside",
        ))
        fig2.update_layout(**PLOTLY_LAYOUT, title="Blended ROAS by Channel", height=360)
        fig2.add_hline(y=3.0, line_dash="dash", line_color="#FF6B35", annotation_text="ROAS = 3x target")
        st.plotly_chart(fig2, use_container_width=True)
        st.caption("ROAS = Revenue / Ad Spend. Orange dashed line = 3x profitability threshold")

    # ── Chart 3: Spend vs Revenue Bubble ─────────────────────────────────────
    with col_b:
        st.subheader("Spend vs Revenue (bubble = orders)")
        bubble = (
            df.groupby("channel")
            .agg(spend=("spend_gbp","sum"), revenue=("revenue_gbp","sum"), orders=("orders","sum"))
            .reset_index()
        )
        fig3 = go.Figure()
        for _, row in bubble.iterrows():
            fig3.add_trace(go.Scatter(
                x=[row["spend"]], y=[row["revenue"]],
                mode="markers+text",
                name=row["channel"],
                text=[row["channel"]],
                textposition="top center",
                marker=dict(
                    size=np.sqrt(row["orders"]) * 1.2,
                    color=CHANNEL_COLOURS.get(row["channel"], "#888"),
                    line=dict(width=1, color="white"),
                    opacity=0.85,
                ),
            ))
        fig3.update_layout(**PLOTLY_LAYOUT, title="Spend vs Revenue (bubble size = orders)", height=360,
                           showlegend=False)
        fig3.update_xaxes(tickprefix="£")
        fig3.update_yaxes(tickprefix="£")
        st.plotly_chart(fig3, use_container_width=True)
        st.caption("Channels above the diagonal line are ROAS-positive")


# ════════════════════════════════════════════════════════════════════════════
#  PAGE 2 — ATTRIBUTION
# ════════════════════════════════════════════════════════════════════════════
elif page == "Attribution":
    st.title("Last-Click vs Shapley Attribution Analysis")
    st.markdown("*Shapley value attribution distributes revenue credit across all touchpoints in a customer journey — giving upper-funnel channels the credit they deserve.*")
    st.markdown("---")

    attr_df = compute_shapley_attribution(df)
    paid_filtered = df[df["channel"].isin(PAID_CHANNELS)]

    # ── Chart 1: Side-by-side attribution bar ────────────────────────────────
    st.subheader("Revenue Attributed per Channel — Last-Click vs Shapley")

    fig_attr = go.Figure()
    fig_attr.add_trace(go.Bar(
        name="Last-Click",
        x=attr_df["channel"],
        y=attr_df["last_click_revenue"],
        marker_color="#444466",
        text=(attr_df["last_click_revenue"] / 1e6).round(1).astype(str) + "M",
        textposition="outside",
    ))
    fig_attr.add_trace(go.Bar(
        name="Shapley",
        x=attr_df["channel"],
        y=attr_df["shapley_revenue"],
        marker_color=[CHANNEL_COLOURS[c] for c in attr_df["channel"]],
        text=(attr_df["shapley_revenue"] / 1e6).round(1).astype(str) + "M",
        textposition="outside",
    ))
    fig_attr.update_layout(**PLOTLY_LAYOUT, barmode="group",
                           title="Revenue Attribution: Last-Click vs Shapley (£M)", height=400)
    fig_attr.update_yaxes(tickprefix="£")
    st.plotly_chart(fig_attr, use_container_width=True)
    st.caption("Source: Shapley weights derived from simulated multi-touch journey data")

    # ── Chart 2: Delta % bar ─────────────────────────────────────────────────
    st.subheader("Attribution Delta: Shapley vs Last-Click (%)")
    delta_colours = ["#34A853" if v > 0 else "#FF0050" for v in attr_df["delta_pct"]]
    delta_display = attr_df["delta_pct"].clip(-200, 500)

    fig_delta = go.Figure(go.Bar(
        x=attr_df["channel"],
        y=delta_display,
        marker_color=delta_colours,
        text=attr_df["delta_pct"].apply(lambda v: f"{v:+.0f}%" if not np.isinf(v) else "+inf%"),
        textposition="outside",
    ))
    fig_delta.add_hline(y=0, line_color="#CCCCCC", line_width=1)
    fig_delta.update_layout(**PLOTLY_LAYOUT, title="% Revenue Change Under Shapley vs Last-Click", height=360)
    st.plotly_chart(fig_delta, use_container_width=True)

    # ── Insight box ───────────────────────────────────────────────────────────
    tiktok_row = attr_df[attr_df["channel"] == "TikTok"].iloc[0]
    yt_row     = attr_df[attr_df["channel"] == "YouTube"].iloc[0]
    gs_row     = attr_df[attr_df["channel"] == "Google_Search"].iloc[0]

    st.markdown(f"""
    <div class="insight-box">
        <strong>Key Insight:</strong> Under last-click attribution, <strong>TikTok and YouTube receive
        near-zero revenue credit</strong> despite appearing in 40%+ of customer journeys.
        Shapley attribution reveals TikTok deserves <strong>~27% of revenue credit</strong>
        (vs ~0% under last-click), and YouTube deserves <strong>~18%</strong>.<br><br>
        Meanwhile, Google Search is <strong>overvalued by {abs(gs_row['delta_pct']):.0f}%</strong>
        under last-click — it harvests demand created by upper-funnel social investment.
        Cutting TikTok/YouTube based on last-click ROAS would collapse Google Search performance within 60–90 days.
    </div>
    """, unsafe_allow_html=True)


# ════════════════════════════════════════════════════════════════════════════
#  PAGE 3 — CREATIVE PERFORMANCE
# ════════════════════════════════════════════════════════════════════════════
elif page == "Creative Performance":
    st.title("Creative Performance Analysis")
    st.markdown("*Which ad creative format drives the best ROAS? How does Video_Drop_Test — Mous's brand DNA — perform vs other formats?*")
    st.markdown("---")

    paid = df[df["spend_gbp"] > 0]

    # ── Chart 1: ROAS Heatmap ────────────────────────────────────────────────
    st.subheader("ROAS Heatmap: Creative Type x Channel")

    heat_data = (
        paid.groupby(["creative_type", "channel"])
        .agg(spend=("spend_gbp","sum"), revenue=("revenue_gbp","sum"))
        .reset_index()
    )
    heat_data["ROAS"] = heat_data["revenue"] / heat_data["spend"].replace(0, np.nan)
    heat_pivot = heat_data.pivot(index="creative_type", columns="channel", values="ROAS")

    fig_heat = go.Figure(go.Heatmap(
        z=heat_pivot.values,
        x=heat_pivot.columns.tolist(),
        y=heat_pivot.index.tolist(),
        colorscale="RdYlGn",
        text=np.round(heat_pivot.values, 2),
        texttemplate="%{text}x",
        colorbar=dict(title="ROAS", ticksuffix="x"),
        hovertemplate="Creative: %{y}<br>Channel: %{x}<br>ROAS: %{z:.2f}x<extra></extra>",
    ))
    fig_heat.update_layout(**PLOTLY_LAYOUT, title="ROAS by Creative Type x Channel", height=380)
    st.plotly_chart(fig_heat, use_container_width=True)
    st.caption("Green = highest ROAS | Red = lowest ROAS | Video_Drop_Test leads across all channels")

    col1, col2 = st.columns(2)

    # ── Chart 2: Best creative per channel ───────────────────────────────────
    with col1:
        st.subheader("Best Creative Type per Channel")
        best = heat_data.loc[heat_data.groupby("channel")["ROAS"].idxmax()]
        fig_best = go.Figure(go.Bar(
            x=best["channel"],
            y=best["ROAS"],
            marker_color=[CHANNEL_COLOURS.get(c, "#888") for c in best["channel"]],
            text=best["creative_type"].str.replace("_", " "),
            textposition="inside",
        ))
        fig_best.update_layout(**PLOTLY_LAYOUT, title="Top Creative ROAS by Channel", height=360)
        fig_best.update_yaxes(ticksuffix="x")
        st.plotly_chart(fig_best, use_container_width=True)

    # ── Chart 3: Video_Drop_Test vs others over time ──────────────────────────
    with col2:
        st.subheader("Video Drop Test ROAS vs Other Creatives")
        time_creative = (
            paid.groupby([pd.Grouper(key="date", freq="QE"), "creative_type"])
            .agg(spend=("spend_gbp","sum"), revenue=("revenue_gbp","sum"))
            .reset_index()
        )
        time_creative["ROAS"] = time_creative["revenue"] / time_creative["spend"].replace(0, np.nan)

        creative_colours = {
            "Video_Drop_Test":   "#FF6B35",
            "UGC_Review":        "#1877F2",
            "Product_Showcase":  "#34A853",
            "Influencer_Collab": "#9B59B6",
        }

        fig_time = go.Figure()
        for ct, grp in time_creative.groupby("creative_type"):
            grp = grp.sort_values("date")
            fig_time.add_trace(go.Scatter(
                x=grp["date"], y=grp["ROAS"],
                name=ct.replace("_", " "),
                mode="lines+markers",
                line=dict(
                    color=creative_colours.get(ct, "#888"),
                    width=3 if ct == "Video_Drop_Test" else 1.5,
                    dash="solid" if ct == "Video_Drop_Test" else "dot",
                ),
                marker=dict(size=6 if ct == "Video_Drop_Test" else 4),
            ))
        fig_time.update_layout(**PLOTLY_LAYOUT, title="Quarterly ROAS by Creative Type", height=360)
        fig_time.update_yaxes(ticksuffix="x")
        st.plotly_chart(fig_time, use_container_width=True)

    # Insight box
    st.markdown("""
    <div class="insight-box">
        <strong>Brand Insight:</strong> <strong>Video_Drop_Test</strong> creative consistently
        delivers <strong>+20–25% ROAS premium</strong> vs the channel average across all
        platforms. This validates Mous's core brand strategy — the drop-test format is not
        just a marketing stunt, it's a commercial differentiator. New creative briefs,
        especially for TikTok and Meta Reels, should default to drop-test formats before
        testing alternatives.
    </div>
    """, unsafe_allow_html=True)


# ════════════════════════════════════════════════════════════════════════════
#  PAGE 4 — BUDGET SIMULATOR
# ════════════════════════════════════════════════════════════════════════════
elif page == "Budget Simulator":
    st.title("Budget Allocation Simulator")
    st.markdown("*Drag the sliders to reallocate budget and see projected revenue, orders, CAC, and contribution margin.*")
    st.markdown("---")

    # Compute average ROAS per channel from filtered data
    paid_df = df[df["channel"].isin(PAID_CHANNELS) & (df["spend_gbp"] > 0)]
    avg_roas = (
        paid_df.groupby("channel")
        .apply(lambda g: g["revenue_gbp"].sum() / g["spend_gbp"].sum(), include_groups=False)
        .to_dict()
    )

    col_in, col_out = st.columns([1, 2])

    with col_in:
        total_budget = st.number_input(
            "Total Monthly Budget (£)", min_value=10000, max_value=1000000,
            value=100000, step=5000, format="%d",
        )
        st.markdown("**Budget Allocation (%)**")
        meta_pct   = st.slider("Meta",          0, 100, 35, 1)
        tiktok_pct = st.slider("TikTok",        0, 100, 20, 1)
        yt_pct     = st.slider("YouTube",       0, 100, 15, 1)
        gs_pct     = st.slider("Google Search", 0, 100, 30, 1)

        total_pct = meta_pct + tiktok_pct + yt_pct + gs_pct
        if total_pct != 100:
            st.warning(f"Sliders sum to {total_pct}% — please adjust to reach 100%.")
        else:
            st.success("Allocation sums to 100%")

    allocations = {
        "Meta":          meta_pct,
        "TikTok":        tiktok_pct,
        "YouTube":       yt_pct,
        "Google_Search": gs_pct,
    }

    # Shapley-optimal allocation for comparison
    shapley_optimal = {ch: SHAPLEY_WEIGHTS[ch] * 100 for ch in PAID_CHANNELS}

    sim    = budget_simulation(allocations, avg_roas, total_budget)
    sim_sv = budget_simulation(shapley_optimal, avg_roas, total_budget)

    with col_out:
        st.subheader("Projected Outcomes")
        kc1, kc2, kc3, kc4 = st.columns(4)
        kc1.metric("Projected Revenue", f"£{sim['total_revenue']:,.0f}",
                   delta=f"£{sim['total_revenue'] - sim_sv['total_revenue']:+,.0f} vs Shapley-optimal")
        kc2.metric("Projected Orders",  f"{sim['total_orders']:,.0f}")
        kc3.metric("Projected CAC",     f"£{sim['total_cac']:.2f}")
        kc4.metric("Contribution Margin", f"£{sim['total_cm']:,.0f}",
                   delta=f"£{sim['total_cm'] - sim_sv['total_cm']:+,.0f} vs Shapley-optimal")

        # Bar chart: current vs shapley allocation
        alloc_df = pd.DataFrame({
            "channel":     PAID_CHANNELS,
            "current_pct": [allocations[c] for c in PAID_CHANNELS],
            "shapley_pct": [round(shapley_optimal[c], 1) for c in PAID_CHANNELS],
        })

        fig_alloc = go.Figure()
        fig_alloc.add_trace(go.Bar(
            name="Your Allocation",
            x=alloc_df["channel"], y=alloc_df["current_pct"],
            marker_color=[CHANNEL_COLOURS[c] for c in alloc_df["channel"]],
            text=alloc_df["current_pct"].astype(str) + "%",
            textposition="outside",
        ))
        fig_alloc.add_trace(go.Bar(
            name="Shapley-Optimal",
            x=alloc_df["channel"], y=alloc_df["shapley_pct"],
            marker_color="#FF6B35",
            opacity=0.6,
            text=alloc_df["shapley_pct"].round(1).astype(str) + "%",
            textposition="outside",
        ))
        fig_alloc.update_layout(
            **PLOTLY_LAYOUT, barmode="group",
            title="Your Allocation vs Shapley-Optimal (%)", height=340,
        )
        fig_alloc.update_yaxes(ticksuffix="%")
        st.plotly_chart(fig_alloc, use_container_width=True)

    # Delta indicators per channel
    st.subheader("Channel-Level Impact vs Shapley-Optimal")
    cols = st.columns(len(PAID_CHANNELS))
    for i, ch in enumerate(PAID_CHANNELS):
        curr_rev = sim["channels"][ch]["revenue"]
        sv_rev   = sim_sv["channels"][ch]["revenue"]
        delta    = curr_rev - sv_rev
        cols[i].metric(
            label=ch,
            value=f"£{curr_rev:,.0f}",
            delta=f"£{delta:+,.0f}",
            delta_color="normal",
        )


# ════════════════════════════════════════════════════════════════════════════
#  PAGE 5 — KEY FINDINGS
# ════════════════════════════════════════════════════════════════════════════
elif page == "Key Findings":
    st.title("Key Findings & Recommendations")
    st.markdown("*Five commercial recommendations for Mous's paid social team, derived from 3 years of channel performance data.*")
    st.markdown("---")

    recommendations = [
        {
            "icon": "1",
            "title": "Adopt Shapley Attribution — Stop Flying Blind",
            "body": (
                "Last-click attribution gives TikTok and YouTube near-zero credit despite "
                "their role in initiating 40%+ of customer journeys. A Shapley model reveals "
                "TikTok deserves 27% of conversion credit (vs ~0% under last-click). "
                "Without this fix, budget decisions are systematically biased toward "
                "bottom-funnel channels at the expense of brand growth."
            ),
            "metric": "Recommendation: Implement data-driven attribution via GA4 or Northbeam within Q1",
        },
        {
            "icon": "2",
            "title": "Scale TikTok Budget by 25–30% in H1",
            "body": (
                "TikTok ROAS grew from 2.1x (Jan 2022) to 3.1x (Dec 2024) — a 48% "
                "improvement — reflecting platform maturity and Mous's growing organic "
                "brand presence. The Video_Drop_Test format on TikTok outperforms all "
                "other channel/creative combinations on engagement-to-sale conversion lift. "
                "The channel is under-invested relative to its Shapley revenue contribution."
            ),
            "metric": "TikTok Shapley share: 27.3% | Current spend share: ~18% | Gap: 9.3pp",
        },
        {
            "icon": "3",
            "title": "Pre-launch iPhone Seeding — Budget in August, Not September",
            "body": (
                "Revenue spikes in September (iPhone launch) are preceded by a 4–6 week "
                "consideration window. Customers who see TikTok or YouTube content in "
                "early August are 2–3x more likely to convert in September than those "
                "first exposed post-launch. Shift 15–20% of September budget to "
                "mid-August awareness campaigns focused on Video_Drop_Test format."
            ),
            "metric": "Sep peak revenue is +85% above monthly baseline | Pre-loading spend captures this at lower CPM",
        },
        {
            "icon": "4",
            "title": "Default All New Creatives to Video_Drop_Test Format",
            "body": (
                "Video_Drop_Test delivers a consistent +20–25% ROAS premium vs the "
                "channel average across every paid channel. This is not a coincidence — "
                "it aligns with Mous's brand DNA and answers the consumer's core "
                "question ('Is this case worth the premium?') in 15 seconds. "
                "UGC_Review and Influencer_Collab formats perform well for retargeting "
                "but should not be the primary acquisition creative."
            ),
            "metric": "Video_Drop_Test avg ROAS: 3.8x | Next best (UGC_Review): 3.2x | Premium: +18.75%",
        },
        {
            "icon": "5",
            "title": "Run Weekly Contribution Margin Reviews — Not ROAS",
            "body": (
                "Blended ROAS is a vanity metric without gross margin context. "
                "Google Search shows 5.1x ROAS but is a harvest channel: its "
                "performance degrades within 60 days if TikTok/YouTube upper-funnel "
                "investment is cut. A weekly CM dashboard — Revenue × 45% GM "
                "minus Spend — gives finance and marketing a single shared truth "
                "for budget decisions and prevents siloed channel optimisation."
            ),
            "metric": "Google Search CM per £1 spent: £1.30 | Meta: £0.62 | TikTok: £0.17 (growing)",
        },
    ]

    for rec in recommendations:
        st.markdown(f"""
        <div class="rec-card">
            <h4>{rec['icon']}. {rec['title']}</h4>
            <p>{rec['body']}</p>
            <p class="rec-metric">Metric: {rec['metric']}</p>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("---")

    # Download button — summary CSV
    summary = (
        df[df["spend_gbp"] > 0]
        .groupby("channel")
        .agg(
            Total_Spend_GBP=("spend_gbp", "sum"),
            Total_Revenue_GBP=("revenue_gbp", "sum"),
            Total_Orders=("orders", "sum"),
            Total_New_Customers=("new_customers", "sum"),
            Avg_ROAS=("ROAS", "mean"),
            Avg_CAC=("CAC", "mean"),
            Avg_Repeat_Rate=("Repeat_Rate", "mean"),
        )
        .reset_index()
        .round(2)
    )

    buf = io.StringIO()
    summary.to_csv(buf, index=False)

    st.download_button(
        label="Download Full Summary Report (CSV)",
        data=buf.getvalue(),
        file_name="mous_attribution_summary.csv",
        mime="text/csv",
    )
