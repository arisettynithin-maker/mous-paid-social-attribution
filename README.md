# Mous Paid Social ROAS Attribution Model
### Channel Efficiency Across Meta, TikTok & YouTube

**Live Demo:** [YOUR_STREAMLIT_URL] ← *Add after deploying to share.streamlit.io*

---

## The Problem I Noticed

D2C brands like Mous run paid social across 4–5 channels simultaneously, but almost universally measure performance using **last-click attribution** — a model that hands 100% of conversion credit to the final ad a customer clicked. In multi-touch journeys (TikTok discovery → Instagram retargeting → Google Search conversion), last-click is blind to 60–70% of the actual influence chain. This leads to systematic under-investment in upper-funnel channels and over-reliance on Google Search, which is a *harvest* channel — it captures demand that social investment created.

---

## My Approach

I built a **Shapley Value attribution model** — the same technique used by Meta's Conversion Lift and Google's Data-Driven Attribution — applied to 3 years of simulated Mous paid social data. The model:

1. Simulates 10 representative multi-touch customer journeys based on typical D2C path patterns
2. Distributes revenue credit across touchpoints using equal Shapley weights
3. Compares per-channel ROAS under Last-Click vs Shapley attribution
4. Surfaces the budget reallocation implied by fair attribution

**Tools:** Python (Pandas, NumPy) for data pipeline | Shapley value attribution model | Streamlit + Plotly for interactive dashboard | SQL for production-ready analytical queries

---

## Key Findings

- **TikTok is undervalued by ~100% under last-click attribution** — it appears in 40%+ of journeys but receives near-zero last-click credit; Shapley assigns it 27.3% of revenue
- **Google Search ROAS of 5.1x is artificially inflated** — it harvests demand created by TikTok/YouTube; cutting social would collapse Search conversion within 60–90 days
- **Video_Drop_Test creative delivers +20–25% ROAS premium** vs all other formats across every channel — validating Mous's viral drop-test brand strategy as a commercial differentiator
- **September iPhone launch drives +85% revenue spike** — pre-loading awareness spend in August (not September) converts more efficiently at lower CPM
- **TikTok ROAS grew 48% from 2022 to 2024** (2.1x → 3.1x) — the platform is maturing into a direct-response channel, not just brand awareness

---

## Business Recommendations

1. **Adopt Shapley attribution** — implement via GA4 data-driven attribution or a measurement partner (Northbeam, Triple Whale) to remove last-click bias from budget decisions
2. **Increase TikTok spend by 25–30%** — current budget share (~18%) is significantly below Shapley revenue contribution (27.3%); reallocate from Google Search
3. **Shift iPhone launch budget to August** — awareness campaigns seeded 4–6 weeks pre-launch capture the consideration phase at 2–3x better efficiency than reactive post-launch spend

---

## Tech Stack

`Python` | `Pandas` | `NumPy` | `SQL (PostgreSQL)` | `Streamlit` | `Plotly` | `Matplotlib` | `Seaborn` | `scikit-learn`

---

## How to Run Locally

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/mous-paid-social-attribution.git
cd mous-paid-social-attribution

# 2. Install dependencies
pip install -r requirements.txt

# 3. Generate the dataset (if not already present)
python data/generate_data.py
python data/process_data.py

# 4. Launch the dashboard
streamlit run app/streamlit_app.py
```

Open [http://localhost:8501](http://localhost:8501) in your browser.

---

## Project Structure

```
mous-paid-social-attribution/
├── data/
│   ├── raw/                          # Raw synthetic dataset (65,760 rows)
│   │   └── mous_paid_social_raw.csv
│   ├── processed/                    # Clean dataset with metrics + attribution
│   │   └── mous_attribution_clean.csv
│   ├── generate_data.py              # Synthetic data generator
│   └── process_data.py               # Processing pipeline + Shapley model
├── notebooks/
│   └── mous_attribution_analysis.ipynb   # 9-section analysis notebook
├── sql/
│   ├── README_sql.md                 # SQL library index
│   ├── 01_channel_spend_vs_revenue.sql
│   ├── 02_first_purchase_by_channel.sql
│   ├── 03_repeat_purchase_rate_by_channel.sql
│   ├── 04_cac_by_channel_monthly.sql
│   ├── 05_ltv_cohort_by_acquisition_channel.sql
│   ├── 06_creative_fatigue_frequency_analysis.sql
│   ├── 07_channel_attribution_lastclick_vs_shapley.sql
│   ├── 08_roas_trend_yoy_by_channel.sql
│   ├── 09_funnel_dropoff_by_channel.sql
│   ├── 10_top_converting_audience_segments.sql
│   ├── 11_budget_allocation_efficiency_index.sql
│   └── 12_channel_overlap_multitouch_paths.sql
├── app/
│   ├── streamlit_app.py              # 5-page interactive dashboard
│   └── utils.py                     # Shared utility functions
├── docs/
│   └── project_notes.md             # Design decisions + deployment guide
├── .streamlit/
│   └── config.toml                  # Dark theme configuration
├── requirements.txt
└── README.md
```

---

## Dashboard Pages

| Page | Description |
|------|-------------|
| **Overview** | KPI cards, monthly revenue stacked area, ROAS bar chart, spend vs revenue bubble chart |
| **Attribution** | Last-Click vs Shapley side-by-side, delta % bar, insight analysis |
| **Creative Performance** | ROAS heatmap (creative x channel), best creative per channel, Video_Drop_Test trend |
| **Budget Simulator** | Interactive sliders to reallocate budget, live projected revenue/orders/CAC/CM |
| **Key Findings** | 5 commercial recommendation cards + downloadable summary CSV |

---

*Built as a portfolio project for a Data Analyst role at Mous. All data is synthetic and generated to reflect realistic D2C paid social performance patterns.*
