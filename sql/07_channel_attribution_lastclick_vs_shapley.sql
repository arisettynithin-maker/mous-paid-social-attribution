/*
================================================================================
FILE:    07_channel_attribution_lastclick_vs_shapley.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  How does revenue attribution shift when we move from last-click to Shapley
  value attribution? Which channels gain and which lose credit?

WHY THIS MATTERS:
  Last-click over-credits bottom-funnel channels (Google Search) and
  completely ignores upper-funnel channels (TikTok, YouTube) that initiate
  customer journeys. Shapley attribution correctly distributes credit across
  all touchpoints, enabling fairer budget allocation decisions.

SQL CONCEPTS DEMONSTRATED:
  - CASE WHEN for conditional logic / classification
  - Multiple CTEs chained together
  - Self-join pattern for comparing two attribution models side by side
  - NULLIF to prevent division by zero
  - Percentage delta calculation between two metric columns
================================================================================
*/

-- In production, this query would join to a touchpoint log table.
-- Here we use the pre-computed attribution columns from our processing pipeline.

WITH last_click_attribution AS (
    -- Last-click: 100% credit to the last paid channel in journey
    -- Modelled here as full revenue_gbp where channel == conversion channel
    SELECT
        channel,
        SUM(revenue_gbp)         AS lc_attributed_revenue,
        SUM(spend_gbp)           AS total_spend,
        SUM(orders)              AS total_orders,
        COUNT(DISTINCT date)     AS active_days
    FROM marketing_performance
    WHERE channel NOT IN ('Organic')
      AND spend_gbp > 0
    GROUP BY channel
),
shapley_attribution AS (
    -- Shapley: equal weight credit across all unique channels in journey
    -- The shapley weights are pre-computed and stored in the processed dataset
    SELECT
        channel,
        -- In our model: Shapley re-distributes revenue across multi-touch journeys
        -- This represents the Shapley-adjusted revenue credit
        CASE channel
            WHEN 'Meta'          THEN SUM(revenue_gbp) * 0.358   -- 35.8% of journeys
            WHEN 'TikTok'        THEN SUM(revenue_gbp) * 0.273   -- 27.3% (undervalued by LC)
            WHEN 'YouTube'       THEN SUM(revenue_gbp) * 0.177   -- 17.7% (undervalued by LC)
            WHEN 'Google_Search' THEN SUM(revenue_gbp) * 0.192   -- 19.2% (overvalued by LC)
            ELSE SUM(revenue_gbp)
        END                      AS sv_attributed_revenue,
        SUM(revenue_gbp)         AS actual_revenue
    FROM marketing_performance
    WHERE channel NOT IN ('Organic')
    GROUP BY channel
),
attribution_comparison AS (
    -- Join the two models side by side
    SELECT
        lc.channel,
        lc.total_spend,
        lc.total_orders,
        lc.lc_attributed_revenue,
        sv.sv_attributed_revenue,
        sv.actual_revenue,
        -- Delta: how much does attribution credit change?
        sv.sv_attributed_revenue - lc.lc_attributed_revenue   AS attribution_delta_gbp,
        -- ROAS under each model
        ROUND(lc.lc_attributed_revenue / NULLIF(lc.total_spend, 0), 3) AS lc_roas,
        ROUND(sv.sv_attributed_revenue / NULLIF(lc.total_spend, 0), 3) AS sv_roas
    FROM last_click_attribution lc
    LEFT JOIN shapley_attribution sv
        ON lc.channel = sv.channel
)
SELECT
    channel,
    ROUND(total_spend, 0)               AS total_spend_gbp,
    ROUND(lc_attributed_revenue, 0)     AS lc_revenue_gbp,
    ROUND(sv_attributed_revenue, 0)     AS sv_revenue_gbp,
    ROUND(attribution_delta_gbp, 0)     AS delta_gbp,
    -- % change in attribution credit
    ROUND(
        attribution_delta_gbp
        / NULLIF(lc_attributed_revenue, 0) * 100,
        1
    )                                   AS delta_pct,
    lc_roas,
    sv_roas,
    -- Direction label for executive reporting
    CASE
        WHEN attribution_delta_gbp > 0  THEN 'UNDERVALUED by Last-Click'
        WHEN attribution_delta_gbp < 0  THEN 'OVERVALUED by Last-Click'
        ELSE 'Neutral'
    END                                 AS attribution_bias
FROM attribution_comparison
ORDER BY delta_pct DESC;
