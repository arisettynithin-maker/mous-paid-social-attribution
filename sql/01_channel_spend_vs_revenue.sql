/*
================================================================================
FILE:    01_channel_spend_vs_revenue.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  What is the total spend, revenue, and blended ROAS for each channel
  across the full 3-year analysis period (Jan 2022 – Dec 2024)?

WHY THIS MATTERS:
  The first step in any paid media audit is understanding the raw P&L by channel.
  ROAS (Revenue / Spend) is the headline efficiency metric. Channels above 3x
  are profitable at a 33% COGS. Channels below 2x require investigation or cut.

SQL CONCEPTS DEMONSTRATED:
  - GROUP BY aggregation
  - SUM(), AVG(), MIN(), MAX() aggregate functions
  - Calculated fields (ROAS, CTR, CPO)
  - ROUND() for clean output
  - ORDER BY for ranking channels by ROAS
  - NULLIF() to avoid division by zero
================================================================================
*/

SELECT
    channel,
    COUNT(*)                                                              AS total_rows,
    SUM(impressions)                                                      AS total_impressions,
    SUM(clicks)                                                           AS total_clicks,
    ROUND(SUM(clicks)::NUMERIC / NULLIF(SUM(impressions), 0) * 100, 3)  AS blended_ctr_pct,
    ROUND(SUM(spend_gbp), 2)                                             AS total_spend_gbp,
    ROUND(SUM(revenue_gbp), 2)                                           AS total_revenue_gbp,
    ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3)             AS blended_roas,
    SUM(orders)                                                          AS total_orders,
    ROUND(SUM(spend_gbp) / NULLIF(SUM(orders), 0), 2)                  AS blended_cpo_gbp,
    SUM(new_customers)                                                   AS total_new_customers,
    ROUND(SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2)           AS blended_cac_gbp,
    ROUND(AVG(avg_order_value_gbp), 2)                                  AS avg_aov_gbp
FROM marketing_performance
WHERE channel != 'Organic'          -- Organic has no spend; exclude from ROAS calc
GROUP BY channel
ORDER BY blended_roas DESC;

-- ── EXTENDED: Full period summary with channel share of total spend ────────
WITH channel_totals AS (
    SELECT
        channel,
        SUM(spend_gbp)   AS spend,
        SUM(revenue_gbp) AS revenue,
        SUM(orders)      AS orders
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY channel
),
grand_total AS (
    SELECT
        SUM(spend)   AS total_spend,
        SUM(revenue) AS total_revenue
    FROM channel_totals
)
SELECT
    ct.channel,
    ROUND(ct.spend, 0)                                              AS spend_gbp,
    ROUND(ct.revenue, 0)                                            AS revenue_gbp,
    ROUND(ct.revenue / NULLIF(ct.spend, 0), 2)                     AS roas,
    ROUND(ct.spend / gt.total_spend * 100, 1)                      AS spend_share_pct,
    ROUND(ct.revenue / gt.total_revenue * 100, 1)                  AS revenue_share_pct
FROM channel_totals ct
CROSS JOIN grand_total gt
ORDER BY roas DESC;
