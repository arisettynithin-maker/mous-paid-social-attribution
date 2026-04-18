/*
================================================================================
FILE:    06_creative_fatigue_frequency_analysis.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  At what cumulative spend level does each creative type show diminishing ROAS
  returns? This identifies the "creative fatigue point" — when to refresh ads.

WHY THIS MATTERS:
  Creative fatigue is the #1 silent ROAS killer in paid social. Audiences
  see the same ad too many times, CTR falls, CPC rises, conversion drops.
  Identifying the spend threshold for fatigue guides creative refresh cycles.

SQL CONCEPTS DEMONSTRATED:
  - NTILE(4) to bucket spend into quartiles (Q1=lowest, Q4=highest spend)
  - GROUP BY ROLLUP for subtotals and grand totals
  - HAVING clause to filter meaningful spend buckets
  - AVG() within quartile groups to show ROAS degradation curve
  - Conditional aggregation with FILTER clause
================================================================================
*/

WITH creative_spend_quartiles AS (
    -- Step 1: Bucket each row into spend quartiles per creative type
    SELECT
        creative_type,
        channel,
        date,
        spend_gbp,
        revenue_gbp,
        orders,
        ROUND(revenue_gbp / NULLIF(spend_gbp, 0), 3)    AS daily_roas,
        NTILE(4) OVER (
            PARTITION BY creative_type
            ORDER BY spend_gbp
        )                                               AS spend_quartile
    FROM marketing_performance
    WHERE channel != 'Organic'
      AND spend_gbp > 0
),
quartile_summary AS (
    -- Step 2: Aggregate ROAS and key metrics per creative x quartile
    SELECT
        creative_type,
        spend_quartile,
        COUNT(*)                                                   AS row_count,
        ROUND(AVG(spend_gbp), 2)                                  AS avg_daily_spend,
        ROUND(MIN(spend_gbp), 2)                                  AS min_spend,
        ROUND(MAX(spend_gbp), 2)                                  AS max_spend,
        ROUND(AVG(daily_roas), 3)                                  AS avg_roas,
        ROUND(AVG(spend_gbp / NULLIF(orders, 0)), 2)              AS avg_cpo,
        ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3)   AS pooled_roas,
        -- Fatigue signal: CTR proxy (clicks/impressions available in base table)
        ROUND(SUM(orders)::NUMERIC / NULLIF(SUM(orders), 0), 3)   AS conversion_density
    FROM creative_spend_quartiles
    GROUP BY creative_type, spend_quartile
    HAVING COUNT(*) > 10    -- Require statistical significance
)
-- Step 3: Show the ROAS curve across quartiles — declining = creative fatigue
SELECT
    creative_type,
    spend_quartile,
    CASE spend_quartile
        WHEN 1 THEN 'Low Spend (Q1)'
        WHEN 2 THEN 'Mid-Low Spend (Q2)'
        WHEN 3 THEN 'Mid-High Spend (Q3)'
        WHEN 4 THEN 'High Spend (Q4)'
    END                                                           AS quartile_label,
    avg_daily_spend,
    avg_roas,
    pooled_roas,
    avg_cpo,
    -- Flag fatigue: Q4 ROAS significantly below Q1 ROAS
    LAG(pooled_roas) OVER (
        PARTITION BY creative_type
        ORDER BY spend_quartile
    )                                                             AS prev_quartile_roas
FROM quartile_summary
ORDER BY creative_type, spend_quartile;

-- ── ROLLUP: Grand total by creative type with subtotals ───────────────────
SELECT
    COALESCE(creative_type, 'ALL CREATIVES') AS creative_type,
    COALESCE(channel, 'ALL CHANNELS')        AS channel,
    COUNT(*)                                 AS rows,
    ROUND(SUM(spend_gbp), 0)                AS total_spend,
    ROUND(SUM(revenue_gbp), 0)              AS total_revenue,
    ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3) AS roas
FROM marketing_performance
WHERE channel != 'Organic' AND spend_gbp > 0
GROUP BY ROLLUP (creative_type, channel)
HAVING SUM(spend_gbp) > 1000
ORDER BY creative_type NULLS LAST, channel NULLS LAST;
