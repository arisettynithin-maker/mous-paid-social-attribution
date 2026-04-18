"""
Mous Paid Social Attribution Model — Synthetic Data Generator
Generates realistic 3-year daily paid social data for a D2C brand (Mous-style).
"""

import pandas as pd
import numpy as np
from datetime import date, timedelta
import os

np.random.seed(42)

START = date(2022, 1, 1)
END   = date(2024, 12, 31)
dates = [START + timedelta(days=i) for i in range((END - START).days + 1)]

CHANNELS = ["Meta", "TikTok", "YouTube", "Google_Search", "Organic"]
CAMPAIGN_TYPES = ["Prospecting", "Retargeting", "Brand_Awareness"]
CREATIVE_TYPES = ["Video_Drop_Test", "UGC_Review", "Product_Showcase", "Influencer_Collab"]

# --- Channel base configs ---
CHANNEL_CONFIG = {
    "Meta":          {"spend_base": 1800, "roas_base": 3.5, "ctr_base": 0.025, "nc_ratio": 0.55},
    "TikTok":        {"spend_base": 400,  "roas_base": 2.6, "ctr_base": 0.035, "nc_ratio": 0.70},
    "YouTube":       {"spend_base": 900,  "roas_base": 1.6, "ctr_base": 0.008, "nc_ratio": 0.45},
    "Google_Search": {"spend_base": 1100, "roas_base": 5.1, "ctr_base": 0.065, "nc_ratio": 0.40},
    "Organic":       {"spend_base": 0,    "roas_base": 0,   "ctr_base": 0.015, "nc_ratio": 0.30},
}

CREATIVE_ROAS_MULT = {
    "Video_Drop_Test":   1.25,
    "UGC_Review":        1.05,
    "Product_Showcase":  0.95,
    "Influencer_Collab": 0.90,
}

CAMPAIGN_SPEND_MULT = {
    "Prospecting":    1.10,
    "Retargeting":    0.65,
    "Brand_Awareness": 0.55,
}

CAMPAIGN_ROAS_MULT = {
    "Prospecting":    0.90,
    "Retargeting":    1.40,
    "Brand_Awareness": 0.70,
}


def seasonality_factor(d: date) -> float:
    """Peak Nov-Dec (Christmas) + Sep (iPhone launch)."""
    m = d.month
    if m == 12:   return 1.85
    if m == 11:   return 1.60
    if m == 9:    return 1.35
    if m == 10:   return 1.15
    if m in (7, 8): return 0.85
    if m in (1, 2): return 0.80
    return 1.0


def tiktok_growth(d: date) -> float:
    """TikTok ramps from 0.30x in Jan-22 to 1.80x by Dec-24."""
    total_days = (END - START).days
    elapsed    = (d - START).days
    return 0.30 + (1.50 * elapsed / total_days)


def yoy_roas_trend(channel: str, d: date) -> float:
    """Slight improvement / saturation trends over 3 years."""
    year_offset = (d.year - 2022) / 2
    trends = {"Meta": 0.95, "TikTok": 1.10, "YouTube": 0.97,
              "Google_Search": 1.02, "Organic": 1.0}
    return 1.0 + year_offset * (trends[channel] - 1.0)


rows = []
for d in dates:
    season  = seasonality_factor(d)
    weekday = d.weekday()
    wd_mult = 1.10 if weekday < 5 else 0.85  # paid heavier Mon–Fri

    for ch in CHANNELS:
        cfg = CHANNEL_CONFIG[ch]
        for ctype in CAMPAIGN_TYPES:
            for crtype in CREATIVE_TYPES:
                if ch == "Organic":
                    # Organic has no spend/paid campaigns
                    impressions  = int(np.random.randint(2000, 8000) * season)
                    clicks       = int(impressions * cfg["ctr_base"] * np.random.uniform(0.8, 1.2))
                    spend_gbp    = 0.0
                    roas_eff     = 0.0
                    revenue_gbp  = round(clicks * np.random.uniform(0.8, 2.5), 2)
                    orders       = max(1, int(revenue_gbp / np.random.uniform(35, 70)))
                    new_cust     = int(orders * cfg["nc_ratio"] * np.random.uniform(0.8, 1.2))
                    ret_cust     = orders - new_cust
                    aov          = round(revenue_gbp / max(orders, 1), 2)
                else:
                    tk_growth = tiktok_growth(d) if ch == "TikTok" else 1.0
                    roas_trend = yoy_roas_trend(ch, d)

                    spend_gbp = round(
                        cfg["spend_base"]
                        * CAMPAIGN_SPEND_MULT[ctype]
                        * season
                        * wd_mult
                        * tk_growth
                        * np.random.uniform(0.70, 1.30),
                        2,
                    )

                    roas_channel_range = {
                        "Meta":          (2.8, 4.2),
                        "TikTok":        (1.9, 3.5),
                        "YouTube":       (1.2, 2.1),
                        "Google_Search": (4.5, 6.2),
                    }
                    lo, hi = roas_channel_range[ch]
                    roas_eff = (
                        np.random.uniform(lo, hi)
                        * CAMPAIGN_ROAS_MULT[ctype]
                        * CREATIVE_ROAS_MULT[crtype]
                        * roas_trend
                    )
                    roas_eff = round(max(roas_eff, 0.5), 3)

                    revenue_gbp = round(spend_gbp * roas_eff, 2)

                    aov_base = {"Meta": 55, "TikTok": 48, "YouTube": 62,
                                "Google_Search": 58, "Organic": 52}[ch]
                    aov = round(np.random.normal(aov_base, 8), 2)
                    aov = max(aov, 25)

                    orders     = max(1, int(revenue_gbp / aov))
                    new_cust   = max(0, int(orders * cfg["nc_ratio"] * np.random.uniform(0.8, 1.2)))
                    ret_cust   = max(0, orders - new_cust)

                    ctr_base_ch = cfg["ctr_base"]
                    impressions = max(1000, int(spend_gbp * np.random.uniform(180, 320)))
                    clicks      = max(1, int(impressions * ctr_base_ch * np.random.uniform(0.7, 1.3)))

                rows.append({
                    "date":                  d.isoformat(),
                    "channel":               ch,
                    "campaign_type":         ctype,
                    "creative_type":         crtype,
                    "impressions":           impressions,
                    "clicks":                clicks,
                    "spend_gbp":             spend_gbp,
                    "orders":                orders,
                    "revenue_gbp":           revenue_gbp,
                    "new_customers":         new_cust,
                    "returning_customers":   ret_cust,
                    "avg_order_value_gbp":   aov,
                })

df_raw = pd.DataFrame(rows)
out_path = os.path.join(os.path.dirname(__file__), "raw", "mous_paid_social_raw.csv")
df_raw.to_csv(out_path, index=False)
print(f"Raw data saved -> {out_path}  ({len(df_raw):,} rows)")
