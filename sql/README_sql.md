# SQL Library — Mous Paid Social ROAS Attribution Model

All queries assume a table called `marketing_performance` with the schema below.
Each file is fully runnable SQL (PostgreSQL syntax) — no placeholders.

## Table Schema

```sql
CREATE TABLE marketing_performance (
    date                  DATE,
    channel               VARCHAR(50),   -- Meta, TikTok, YouTube, Google_Search, Organic
    campaign_type         VARCHAR(50),   -- Prospecting, Retargeting, Brand_Awareness
    creative_type         VARCHAR(50),   -- Video_Drop_Test, UGC_Review, Product_Showcase, Influencer_Collab
    impressions           INTEGER,
    clicks                INTEGER,
    spend_gbp             NUMERIC(12,2),
    orders                INTEGER,
    revenue_gbp           NUMERIC(12,2),
    new_customers         INTEGER,
    returning_customers   INTEGER,
    avg_order_value_gbp   NUMERIC(10,2)
);
```

---

## Query Index

| File | Business Question | SQL Concepts Demonstrated |
|------|-------------------|---------------------------|
| [01_channel_spend_vs_revenue.sql](01_channel_spend_vs_revenue.sql) | What is total spend, revenue, and ROAS per channel across 3 years? | `GROUP BY`, `SUM()`, `ROUND()`, `NULLIF()`, calculated fields, `ORDER BY`, CTE with `CROSS JOIN` |
| [02_first_purchase_by_channel.sql](02_first_purchase_by_channel.sql) | Which channel drives highest new customer acquisition monthly? | `DATE_TRUNC`, `EXTRACT`, `RANK() OVER (PARTITION BY month ORDER BY new_customers DESC)`, CTE, `FILTER` |
| [03_repeat_purchase_rate_by_channel.sql](03_repeat_purchase_rate_by_channel.sql) | Which channel acquires customers with highest repeat purchase rate? | `CAST`, `ROUND`, ratio aggregation, `HAVING`, `CASE WHEN` loyalty tier |
| [04_cac_by_channel_monthly.sql](04_cac_by_channel_monthly.sql) | How has CAC trended monthly by channel over 3 years? | `DATE_TRUNC`, `LAG()` for MoM change, multi-step CTEs, rolling `AVG()` window, alert flags |
| [05_ltv_cohort_by_acquisition_channel.sql](05_ltv_cohort_by_acquisition_channel.sql) | What is the 90-day LTV per acquisition channel cohort? | Multi-step CTE chain, cohort logic, `INTERVAL` date arithmetic, `LEFT JOIN`, LTV/CAC ratio |
| [06_creative_fatigue_frequency_analysis.sql](06_creative_fatigue_frequency_analysis.sql) | At what spend level does each creative show diminishing ROAS? | `NTILE(4)` quartile bucketing, `GROUP BY ROLLUP`, `HAVING`, `LAG()` for ROAS curve |
| [07_channel_attribution_lastclick_vs_shapley.sql](07_channel_attribution_lastclick_vs_shapley.sql) | How does revenue attribution shift between Last-Click and Shapley? | `CASE WHEN`, multiple CTEs, self-join pattern, `NULLIF`, attribution bias labelling |
| [08_roas_trend_yoy_by_channel.sql](08_roas_trend_yoy_by_channel.sql) | Is ROAS improving or declining YoY per channel? | `DATE_PART`, `LAG()` for YoY comparison, `DENSE_RANK()`, trend classification |
| [09_funnel_dropoff_by_channel.sql](09_funnel_dropoff_by_channel.sql) | Where in the funnel does each channel lose the most users? | Multi-stage funnel CTEs, percentage drop-off, `LEAD()`, bottleneck diagnosis `CASE WHEN` |
| [10_top_converting_audience_segments.sql](10_top_converting_audience_segments.sql) | Which campaign_type + channel combo has best conversion efficiency? | Multi-column `GROUP BY`, `RANK() OVER PARTITION`, correlated subquery, composite scoring |
| [11_budget_allocation_efficiency_index.sql](11_budget_allocation_efficiency_index.sql) | How should £100k be optimally split across channels by CM efficiency? | Contribution margin, `PERCENT_RANK()`, `GROUP BY CUBE`, multi-step CTE, budget modelling |
| [12_channel_overlap_multitouch_paths.sql](12_channel_overlap_multitouch_paths.sql) | Which channel combinations appear most in multi-touch paths? | Self-join, `EXISTS` semi-join, `NOT EXISTS` anti-join, `STRING_AGG`, journey path analysis |

---

## Key Definitions

| Metric | Formula | Business Meaning |
|--------|---------|------------------|
| **ROAS** | `revenue_gbp / spend_gbp` | Revenue generated per £1 of ad spend |
| **CAC** | `spend_gbp / new_customers` | Cost to acquire one new customer |
| **CPO** | `spend_gbp / orders` | Cost per order (includes returning customers) |
| **CTR** | `clicks / impressions * 100` | % of people who clicked the ad |
| **CVR** | `orders / clicks * 100` | % of clickers who purchased |
| **Repeat Rate** | `returning_customers / total_customers * 100` | % of orders from existing customers |
| **Contribution Margin** | `revenue_gbp * 0.45 - spend_gbp` | Gross profit after media cost (45% GM assumed) |
| **Shapley ROAS** | `shapley_revenue / spend_gbp` | ROAS using fair multi-touch attribution |

---

## SQL Concepts Coverage Map

| Concept | Files |
|---------|-------|
| Window Functions (`RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `NTILE`, `PERCENT_RANK`) | 02, 04, 06, 08, 09, 10, 11 |
| CTEs (Common Table Expressions) | 04, 05, 06, 07, 08, 09, 10, 11, 12 |
| Aggregation + `HAVING` | 01, 03, 06, 12 |
| `GROUP BY ROLLUP / CUBE` | 06, 11 |
| Self-join | 07, 12 |
| Semi-join (`EXISTS`) / Anti-join (`NOT EXISTS`) | 12 |
| Correlated Subquery | 10 |
| Date Functions (`DATE_TRUNC`, `DATE_PART`, `INTERVAL`) | 02, 04, 05, 08 |
| `STRING_AGG` | 12 |
| `CASE WHEN` Classification | 03, 07, 08, 09, 10 |
| Division-by-zero safety (`NULLIF`) | 01, 02, 04, 05, 07, 08, 09, 10, 11 |
