"""
Mous Paid Social Attribution Model — Data Processing Pipeline
Cleans raw data, computes derived metrics, and builds Shapley attribution.
"""

import pandas as pd
import numpy as np
import os, itertools

np.random.seed(42)

RAW_PATH  = os.path.join(os.path.dirname(__file__), "raw",       "mous_paid_social_raw.csv")
OUT_PATH  = os.path.join(os.path.dirname(__file__), "processed", "mous_attribution_clean.csv")

# ── 1. Load & parse ──────────────────────────────────────────────────────────
df = pd.read_csv(RAW_PATH, parse_dates=["date"])

# ── 2. Time columns ──────────────────────────────────────────────────────────
df["year"]        = df["date"].dt.year
df["month"]       = df["date"].dt.month
df["quarter"]     = df["date"].dt.quarter
df["week_number"] = df["date"].dt.isocalendar().week.astype(int)

# ── 3. Derived metrics ───────────────────────────────────────────────────────
df["CTR"]   = np.where(df["impressions"] > 0, df["clicks"] / df["impressions"], 0)
df["CPC"]   = np.where(df["clicks"]      > 0, df["spend_gbp"] / df["clicks"],      0)
df["CPO"]   = np.where(df["orders"]      > 0, df["spend_gbp"] / df["orders"],       0)
df["ROAS"]  = np.where(df["spend_gbp"]   > 0, df["revenue_gbp"] / df["spend_gbp"],  0)
df["CAC"]   = np.where(df["new_customers"] > 0,
                       df["spend_gbp"] / df["new_customers"], 0)
total_cust  = df["new_customers"] + df["returning_customers"]
df["Repeat_Rate"] = np.where(total_cust > 0,
                              df["returning_customers"] / total_cust, 0)
df["Contribution_Margin_Proxy"] = df["revenue_gbp"] * 0.45 - df["spend_gbp"]

# ── 4. Shapley Value Attribution ─────────────────────────────────────────────
# Simulate multi-touch journeys and distribute revenue credit.
PAID_CHANNELS = ["Meta", "TikTok", "YouTube", "Google_Search"]

# 4a. Build representative journey pool
JOURNEY_TEMPLATES = [
    (["TikTok", "Meta", "Google_Search"], 0.22),
    (["Meta", "Google_Search"],            0.18),
    (["YouTube", "Meta", "Google_Search"], 0.12),
    (["TikTok", "Google_Search"],          0.10),
    (["Meta", "Meta", "Google_Search"],    0.09),
    (["YouTube", "Meta"],                  0.07),
    (["Google_Search"],                    0.06),
    (["Meta"],                             0.05),
    (["TikTok", "Meta"],                   0.06),
    (["YouTube", "Google_Search"],         0.05),
]


def equal_shapley(journey: list) -> dict:
    """Simple equal-weight Shapley for ordered touchpoints."""
    unique_ch = list(dict.fromkeys(journey))  # preserve order, deduplicate
    weight    = 1.0 / len(unique_ch)
    return {ch: weight for ch in unique_ch}


# 4b. Aggregate channel-level revenue for last-click and Shapley
monthly_agg = (
    df[df["channel"].isin(PAID_CHANNELS)]
    .groupby(["year", "month", "channel"])["revenue_gbp"]
    .sum()
    .reset_index()
)

shapley_credits = {ch: 0.0 for ch in PAID_CHANNELS}
lastclick_credits = {ch: 0.0 for ch in PAID_CHANNELS}

total_rev = monthly_agg["revenue_gbp"].sum()

for journey, share in JOURNEY_TEMPLATES:
    journey_rev = total_rev * share
    # Last-click -> 100% to last paid channel
    last_ch = journey[-1]
    if last_ch in lastclick_credits:
        lastclick_credits[last_ch] += journey_rev

    # Shapley -> equal split across unique channels
    sv = equal_shapley(journey)
    for ch, w in sv.items():
        if ch in shapley_credits:
            shapley_credits[ch] += journey_rev * w

# Normalise to match total_rev
lc_total  = sum(lastclick_credits.values())
sv_total  = sum(shapley_credits.values())
lastclick_credits = {k: v / lc_total * total_rev for k, v in lastclick_credits.items()}
shapley_credits   = {k: v / sv_total  * total_rev for k, v in shapley_credits.items()}

# 4c. Merge attribution back onto df as per-row proportional columns
channel_rev = (
    df[df["channel"].isin(PAID_CHANNELS)]
    .groupby("channel")["revenue_gbp"]
    .sum()
    .to_dict()
)

def row_attribution(row, credit_dict):
    ch  = row["channel"]
    rev = row["revenue_gbp"]
    if ch not in credit_dict or channel_rev.get(ch, 0) == 0:
        return 0.0
    return rev * (credit_dict[ch] / channel_rev[ch])

df["revenue_lastclick"]  = df.apply(lambda r: row_attribution(r, lastclick_credits), axis=1)
df["revenue_shapley"]    = df.apply(lambda r: row_attribution(r, shapley_credits),   axis=1)
df["shapley_vs_lc_delta_pct"] = np.where(
    df["revenue_lastclick"] > 0,
    (df["revenue_shapley"] - df["revenue_lastclick"]) / df["revenue_lastclick"] * 100,
    0,
)

# ── 5. Save ──────────────────────────────────────────────────────────────────
df.to_csv(OUT_PATH, index=False)
print(f"Processed data saved -> {OUT_PATH}  ({len(df):,} rows, {df.shape[1]} cols)")
print("\nChannel Shapley vs Last-Click summary:")
for ch in PAID_CHANNELS:
    lc = lastclick_credits[ch]
    sv = shapley_credits[ch]
    delta = (sv - lc) / lc * 100
    print(f"  {ch:<16}  LC={lc:>12,.0f}  SV={sv:>12,.0f}  delta={delta:+.1f}%")
