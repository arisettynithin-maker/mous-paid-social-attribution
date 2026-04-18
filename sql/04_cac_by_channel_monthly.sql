/*
================================================================================
FILE:    04_cac_by_channel_monthly.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  How has Customer Acquisition Cost (CAC) trended monthly per channel
  over the 3-year period? Which channels are becoming more or less efficient?

WHY THIS MATTERS:
  Rising CAC signals market saturation or creative fatigue. Declining CAC
  indicates improving targeting or compounding brand awareness. This query
  is the foundation for weekly budget reallocation decisions.

SQL CONCEPTS DEMONSTRATED:
  - CTE (Common Table Expression) for clean multi-step logic
  - DATE_TRUNC for monthly bucketing
  - LAG() window function for month-over-month CAC change
  - Percentage change calculation
  - NULLIF to prevent division by zero in LAG comparisons
================================================================================
*/

WITH monthly_cac AS (
    -- Step 1: Calculate monthly CAC per channel
    SELECT
        DATE_TRUNC('month', date::DATE) AS month_start,
        channel,
        SUM(spend_gbp)                  AS monthly_spend,
        SUM(new_customers)              AS monthly_new_customers,
        ROUND(
            SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2
        )                               AS cac_gbp
    FROM marketing_performance
    WHERE channel != 'Organic'
      AND new_customers > 0
    GROUP BY
        DATE_TRUNC('month', date::DATE),
        channel
),
cac_with_lag AS (
    -- Step 2: Add previous month's CAC using LAG()
    SELECT
        month_start,
        channel,
        monthly_spend,
        monthly_new_customers,
        cac_gbp,
        LAG(cac_gbp) OVER (
            PARTITION BY channel
            ORDER BY month_start
        ) AS prev_month_cac,
        LAG(monthly_new_customers) OVER (
            PARTITION BY channel
            ORDER BY month_start
        ) AS prev_month_new_customers
    FROM monthly_cac
),
cac_mom_change AS (
    -- Step 3: Calculate MoM % change in CAC
    SELECT
        month_start,
        channel,
        monthly_spend,
        monthly_new_customers,
        cac_gbp,
        prev_month_cac,
        ROUND(
            (cac_gbp - prev_month_cac) / NULLIF(prev_month_cac, 0) * 100, 1
        ) AS cac_mom_change_pct,
        -- Flag significant spikes (>20% MoM CAC increase)
        CASE
            WHEN (cac_gbp - prev_month_cac) / NULLIF(prev_month_cac, 0) > 0.20
                THEN 'ALERT: CAC spike >20%'
            WHEN (cac_gbp - prev_month_cac) / NULLIF(prev_month_cac, 0) < -0.15
                THEN 'POSITIVE: CAC fell >15%'
            ELSE 'Normal'
        END AS cac_flag
    FROM cac_with_lag
)
SELECT
    month_start,
    channel,
    monthly_spend,
    monthly_new_customers,
    cac_gbp,
    prev_month_cac,
    cac_mom_change_pct,
    cac_flag
FROM cac_mom_change
ORDER BY channel, month_start;

-- ── ROLLING 3-MONTH AVERAGE CAC per channel ────────────────────────────────
WITH monthly_cac AS (
    SELECT
        DATE_TRUNC('month', date::DATE) AS month_start,
        channel,
        ROUND(SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2) AS cac_gbp
    FROM marketing_performance
    WHERE channel != 'Organic' AND new_customers > 0
    GROUP BY DATE_TRUNC('month', date::DATE), channel
)
SELECT
    month_start,
    channel,
    cac_gbp,
    ROUND(AVG(cac_gbp) OVER (
        PARTITION BY channel
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3m_avg_cac
FROM monthly_cac
ORDER BY channel, month_start;
