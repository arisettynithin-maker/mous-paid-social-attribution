"""Shared utilities for the Mous Attribution Streamlit app."""

import pandas as pd
import numpy as np

CHANNEL_COLOURS = {
    "Meta":          "#1877F2",
    "TikTok":        "#FF0050",
    "YouTube":       "#FF0000",
    "Google_Search": "#34A853",
    "Organic":       "#9B59B6",
}

PAID_CHANNELS = ["Meta", "TikTok", "YouTube", "Google_Search"]

SHAPLEY_WEIGHTS = {
    "Meta":          0.358,
    "TikTok":        0.273,
    "YouTube":       0.177,
    "Google_Search": 0.192,
}


def load_data(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["date"])
    return df


def apply_filters(
    df: pd.DataFrame,
    start_date,
    end_date,
    channels: list,
    campaign_types: list,
    creative_types: list,
) -> pd.DataFrame:
    mask = (
        (df["date"] >= pd.Timestamp(start_date))
        & (df["date"] <= pd.Timestamp(end_date))
        & (df["channel"].isin(channels))
        & (df["campaign_type"].isin(campaign_types))
        & (df["creative_type"].isin(creative_types))
    )
    return df[mask].copy()


def compute_kpis(df: pd.DataFrame) -> dict:
    paid = df[df["spend_gbp"] > 0]
    total_revenue    = df["revenue_gbp"].sum()
    total_spend      = df["spend_gbp"].sum()
    blended_roas     = total_revenue / total_spend if total_spend > 0 else 0
    total_new_cust   = df["new_customers"].sum()
    avg_cac          = total_spend / total_new_cust if total_new_cust > 0 else 0
    total_ret        = df["returning_customers"].sum()
    total_cust       = total_new_cust + total_ret
    repeat_rate      = total_ret / total_cust * 100 if total_cust > 0 else 0
    return {
        "total_revenue":  total_revenue,
        "blended_roas":   blended_roas,
        "avg_cac":        avg_cac,
        "repeat_rate":    repeat_rate,
        "total_spend":    total_spend,
        "total_orders":   df["orders"].sum(),
    }


def compute_shapley_attribution(df: pd.DataFrame) -> pd.DataFrame:
    """Return per-channel Last-Click vs Shapley revenue comparison."""
    paid = df[df["channel"].isin(PAID_CHANNELS)]
    channel_rev = paid.groupby("channel")["revenue_gbp"].sum().to_dict()
    total_rev   = sum(channel_rev.values())

    lc_shares = {"Meta": 0.82, "TikTok": 0.00, "YouTube": 0.00, "Google_Search": 1.00}
    lc_credits = {
        ch: channel_rev.get(ch, 0) * lc_shares.get(ch, 0.5)
        for ch in PAID_CHANNELS
    }
    lc_total = sum(lc_credits.values())
    if lc_total > 0:
        lc_credits = {k: v / lc_total * total_rev for k, v in lc_credits.items()}

    sv_credits = {ch: total_rev * SHAPLEY_WEIGHTS[ch] for ch in PAID_CHANNELS}

    rows = []
    for ch in PAID_CHANNELS:
        lc = lc_credits.get(ch, 0)
        sv = sv_credits.get(ch, 0)
        delta_pct = (sv - lc) / lc * 100 if lc > 0 else float("inf")
        rows.append({
            "channel": ch,
            "last_click_revenue": lc,
            "shapley_revenue":    sv,
            "delta_pct":          delta_pct,
        })
    return pd.DataFrame(rows)


def budget_simulation(allocations: dict, avg_roas: dict, total_budget: float) -> dict:
    """Simulate revenue given channel budget split and average ROAS."""
    results = {}
    total_revenue   = 0
    total_orders    = 0
    total_new_cust  = 0

    for ch, pct in allocations.items():
        spend    = total_budget * pct / 100
        roas     = avg_roas.get(ch, 2.5)
        revenue  = spend * roas
        aov      = {"Meta": 55, "TikTok": 48, "YouTube": 62, "Google_Search": 58}.get(ch, 55)
        orders   = revenue / aov if aov > 0 else 0
        nc_ratio = {"Meta": 0.55, "TikTok": 0.70, "YouTube": 0.45, "Google_Search": 0.40}.get(ch, 0.5)
        new_cust = orders * nc_ratio
        cm       = revenue * 0.45 - spend
        results[ch] = {
            "spend":       spend,
            "revenue":     revenue,
            "orders":      orders,
            "new_cust":    new_cust,
            "cm":          cm,
        }
        total_revenue  += revenue
        total_orders   += orders
        total_new_cust += new_cust

    total_cm  = total_revenue * 0.45 - total_budget
    total_cac = total_budget / total_new_cust if total_new_cust > 0 else 0

    return {
        "channels":      results,
        "total_revenue": total_revenue,
        "total_orders":  total_orders,
        "total_cac":     total_cac,
        "total_cm":      total_cm,
    }
