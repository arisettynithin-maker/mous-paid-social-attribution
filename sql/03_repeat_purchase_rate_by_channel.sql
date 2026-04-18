/*
================================================================================
FILE:    03_repeat_purchase_rate_by_channel.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Which acquisition channel delivers customers with the highest repeat
  purchase rate? This metric reveals which channel acquires higher-quality,
  more loyal customers — a crucial LTV signal.

WHY THIS MATTERS:
  A channel may look expensive on CAC but cheap on LTV if it acquires
  customers who return 3x per year. Repeat Rate bridges media efficiency
  to commercial LTV modelling.

SQL CONCEPTS DEMONSTRATED:
  - CAST for explicit type conversion (INTEGER division fix)
  - ROUND() for metric formatting
  - Aggregation with ratio calculation
  - HAVING clause to filter low-volume channels (statistical validity)
  - Sorting by business-relevant metric
  - Conditional aggregation with CASE WHEN
================================================================================
*/

SELECT
    channel,
    SUM(new_customers)                                                      AS total_new_customers,
    SUM(returning_customers)                                                AS total_returning_customers,
    SUM(new_customers) + SUM(returning_customers)                          AS total_customers,
    ROUND(
        CAST(SUM(returning_customers) AS NUMERIC)
        / NULLIF(SUM(new_customers) + SUM(returning_customers), 0) * 100,
        2
    )                                                                       AS repeat_rate_pct,
    ROUND(SUM(spend_gbp), 0)                                               AS total_spend_gbp,
    ROUND(SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2)              AS cac_gbp,
    ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3)               AS roas,
    -- Segment quality: High = >45% repeat, Mid = 30-45%, Low = <30%
    CASE
        WHEN CAST(SUM(returning_customers) AS NUMERIC)
             / NULLIF(SUM(new_customers) + SUM(returning_customers), 0) >= 0.45
            THEN 'High Loyalty'
        WHEN CAST(SUM(returning_customers) AS NUMERIC)
             / NULLIF(SUM(new_customers) + SUM(returning_customers), 0) >= 0.30
            THEN 'Mid Loyalty'
        ELSE 'Low Loyalty'
    END                                                                     AS loyalty_tier
FROM marketing_performance
GROUP BY channel
HAVING SUM(new_customers) > 100     -- Filter out statistically insignificant rows
ORDER BY repeat_rate_pct DESC;

-- ── BY CAMPAIGN TYPE: Does Retargeting bring back more repeat buyers? ──────
SELECT
    channel,
    campaign_type,
    SUM(new_customers)                                       AS new_customers,
    SUM(returning_customers)                                 AS returning_customers,
    ROUND(
        CAST(SUM(returning_customers) AS NUMERIC)
        / NULLIF(SUM(new_customers) + SUM(returning_customers), 0) * 100,
        1
    )                                                        AS repeat_rate_pct,
    ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 2) AS roas
FROM marketing_performance
WHERE channel != 'Organic'
GROUP BY channel, campaign_type
HAVING SUM(orders) > 50
ORDER BY channel, repeat_rate_pct DESC;
