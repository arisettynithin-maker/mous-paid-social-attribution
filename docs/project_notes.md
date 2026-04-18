# Project Notes — Mous Paid Social ROAS Attribution Model

## Design Decisions

### Why Shapley Value Attribution?
Shapley values from cooperative game theory distribute a coalition's total payoff fairly
among players. Applied to marketing: each channel is a "player", the "payoff" is the
conversion revenue, and Shapley assigns credit proportional to each channel's marginal
contribution across all possible journey orderings. It is the only attribution method that
satisfies Efficiency, Symmetry, Null Player, and Additivity axioms simultaneously.

### Why Synthetic Data?
Real Mous performance data is not publicly available. The synthetic dataset is built with:
- Realistic ROAS ranges validated against industry benchmarks (Meta 2.8–4.2x, Google 4.5–6.2x)
- Platform-accurate growth curves (TikTok 48% ROAS improvement over 3 years)
- Seasonality grounded in actual D2C patterns (Sep iPhone launch, Nov-Dec gifting)
- Channel mix reflecting typical £3–5M D2C paid social budgets

### Contribution Margin Proxy
Gross margin assumed at 45% — consistent with premium phone accessories manufacturing
at Mous's scale (injection-moulded cases, carbon fibre, Kevlar). Actual GM varies by
SKU and is commercially sensitive.

---

## Deployment Instructions

### Step 1: Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit: Mous Paid Social ROAS Attribution Model"

# Create a new repo at github.com → name it: mous-paid-social-attribution
git remote add origin https://github.com/YOUR_USERNAME/mous-paid-social-attribution.git
git branch -M main
git push -u origin main
```

### Step 2: Deploy on Streamlit Cloud

1. Go to [share.streamlit.io](https://share.streamlit.io)
2. Sign in with your GitHub account
3. Click **"New app"**
4. Select your repo: `mous-paid-social-attribution`
5. Set **main file path**: `app/streamlit_app.py`
6. Set **Python version**: 3.12
7. Click **Deploy**
8. Wait 2–3 minutes for the build to complete
9. Copy the live URL (format: `https://YOUR_USERNAME-mous-paid-social-attribution-appstreamlit-app-XXXXX.streamlit.app`)

### Step 3: Update README

Add the live Streamlit URL to [README.md](../README.md) under the **Live Demo** section.

### Step 4: LinkedIn Portfolio Post (optional)

Share the GitHub repo + Streamlit URL with:
- Screenshot of the Overview page
- Screenshot of the Attribution page
- 2–3 sentence summary of the key insight (TikTok undervaluation)

---

## Known Limitations

1. **Synthetic data** — while realistic, it does not represent Mous's actual performance
2. **Simplified Shapley** — equal-weight Shapley across journey positions; production would use
   game-theoretic Shapley with frequency-weighted journey sampling
3. **45% GM assumption** — actual gross margin varies by product line
4. **No incrementality testing** — geo holdout or PSA tests would validate channel incrementality

---

## File Index

| Path | Purpose |
|------|---------|
| `data/raw/mous_paid_social_raw.csv` | Raw synthetic dataset (65,760 rows) |
| `data/processed/mous_attribution_clean.csv` | Processed dataset with derived metrics + Shapley |
| `data/generate_data.py` | Data generation script |
| `data/process_data.py` | Data processing pipeline |
| `notebooks/mous_attribution_analysis.ipynb` | 9-section analysis notebook |
| `sql/01–12_*.sql` | 12 production-ready SQL queries |
| `sql/README_sql.md` | SQL library index |
| `app/streamlit_app.py` | 5-page interactive dashboard |
| `app/utils.py` | Shared utility functions |
| `.streamlit/config.toml` | Dark theme configuration |
| `requirements.txt` | Python dependencies |
| `README.md` | Project overview / portfolio page |
