/*
================================================================================
FILE:    11_budget_allocation_efficiency_index.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  How should a £100,000 monthly budget be optimally split across channels
  to maximise contribution margin? What is the efficiency index for each channel?

WHY THIS MATTERS:
  Most media teams allocate budget based on historical spend patterns or
  gut feel. This query provides a data-driven allocation recommendation
  based on contribution margin efficiency — the metric the CFO cares about.

SQL CONCEPTS DEMONSTRATED:
  - Contribution margin calculation (Revenue * gross_margin_pct - Spend)
  - PERCENT_RANK() for efficiency percentile ranking
  - CUBE aggregation for multi-dimensional rollups
  - Multi-step CTE for allocation modelling
  - Budget allocation optimisation logic
================================================================================
*/

WITH channel_efficiency AS (
    -- Step 1: Calculate contribution margin metrics per channel
    SELECT
        channel,
        SUM(spend_gbp)                                                AS total_spend,
        SUM(revenue_gbp)                                              AS total_revenue,
        SUM(orders)                                                   AS total_orders,
        -- Contribution Margin = Revenue * Gross Margin (45%) - Media Spend
        ROUND(SUM(revenue_gbp) * 0.45 - SUM(spend_gbp), 2)          AS contribution_margin,
        ROUND(
            (SUM(revenue_gbp) * 0.45 - SUM(spend_gbp))
            / NULLIF(SUM(spend_gbp), 0),
            4
        )                                                             AS cm_per_gbp_spent,
        ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3)      AS roas
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY channel
),
efficiency_ranked AS (
    -- Step 2: Rank channels by CM efficiency using PERCENT_RANK
    SELECT
        channel,
        total_spend,
        total_revenue,
        contribution_margin,
        cm_per_gbp_spent,
        roas,
        -- PERCENT_RANK: 1.0 = most efficient, 0.0 = least efficient
        ROUND(
            PERCENT_RANK() OVER (ORDER BY cm_per_gbp_spent ASC),
            4
        )                                                             AS efficiency_percentile,
        -- Normalised score 0-100
        ROUND(
            (cm_per_gbp_spent - MIN(cm_per_gbp_spent) OVER ())
            / NULLIF(MAX(cm_per_gbp_spent) OVER () - MIN(cm_per_gbp_spent) OVER (), 0)
            * 100,
            1
        )                                                             AS efficiency_score_0_100
    FROM channel_efficiency
),
budget_allocation AS (
    -- Step 3: Recommend £100k allocation based on efficiency scores
    SELECT
        channel,
        cm_per_gbp_spent,
        roas,
        efficiency_score_0_100,
        -- Current spend distribution (historical)
        ROUND(total_spend / SUM(total_spend) OVER () * 100, 1)       AS current_spend_share_pct,
        -- Recommended allocation: proportional to efficiency score
        ROUND(
            efficiency_score_0_100 / NULLIF(SUM(efficiency_score_0_100) OVER (), 0) * 100,
            1
        )                                                             AS recommended_spend_share_pct,
        -- £ amount for £100k budget
        ROUND(
            efficiency_score_0_100 / NULLIF(SUM(efficiency_score_0_100) OVER (), 0) * 100000,
            0
        )                                                             AS recommended_spend_100k_budget,
        -- Projected revenue at recommended allocation
        ROUND(
            efficiency_score_0_100 / NULLIF(SUM(efficiency_score_0_100) OVER (), 0) * 100000
            * roas,
            0
        )                                                             AS projected_revenue
    FROM efficiency_ranked
)
SELECT
    channel,
    ROUND(cm_per_gbp_spent, 3)            AS cm_per_gbp,
    roas,
    efficiency_score_0_100,
    current_spend_share_pct,
    recommended_spend_share_pct,
    recommended_spend_100k_budget         AS recommended_gbp_of_100k,
    projected_revenue                     AS projected_revenue_gbp
FROM budget_allocation
ORDER BY recommended_spend_share_pct DESC;

-- ── CUBE: Multi-dimensional rollup across channel x campaign_type ──────────
SELECT
    COALESCE(channel, 'ALL')        AS channel,
    COALESCE(campaign_type, 'ALL')  AS campaign_type,
    ROUND(SUM(spend_gbp), 0)        AS spend,
    ROUND(SUM(revenue_gbp), 0)      AS revenue,
    ROUND(
        (SUM(revenue_gbp) * 0.45 - SUM(spend_gbp))
        / NULLIF(SUM(spend_gbp), 0), 3
    )                               AS cm_per_gbp
FROM marketing_performance
WHERE channel != 'Organic'
GROUP BY CUBE (channel, campaign_type)
ORDER BY channel NULLS LAST, campaign_type NULLS LAST;
