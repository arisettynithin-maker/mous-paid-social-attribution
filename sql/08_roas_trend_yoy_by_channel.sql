/*
================================================================================
FILE:    08_roas_trend_yoy_by_channel.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Is ROAS improving or declining year-over-year per channel?
  Are we getting better or worse at converting paid spend into revenue?

WHY THIS MATTERS:
  Declining ROAS YoY signals market saturation, audience exhaustion, or
  competitive pressure. Improving ROAS indicates better targeting, creative
  quality, or positive brand flywheel effects. This query feeds the exec
  summary for quarterly business reviews.

SQL CONCEPTS DEMONSTRATED:
  - DATE_PART() for extracting year from date
  - LAG() for year-over-year comparison
  - DENSE_RANK() for ranking channels by ROAS improvement
  - Percentage change calculation with sign interpretation
  - Multiple window functions in one query
================================================================================
*/

WITH annual_roas AS (
    -- Step 1: Annual ROAS per channel
    SELECT
        DATE_PART('year', date::DATE)::INT  AS year,
        channel,
        SUM(spend_gbp)                      AS annual_spend,
        SUM(revenue_gbp)                    AS annual_revenue,
        SUM(orders)                         AS annual_orders,
        SUM(new_customers)                  AS annual_new_customers,
        ROUND(
            SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3
        )                                   AS annual_roas,
        ROUND(
            SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2
        )                                   AS annual_cac
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY
        DATE_PART('year', date::DATE)::INT,
        channel
),
roas_yoy AS (
    -- Step 2: Attach previous year's ROAS using LAG()
    SELECT
        year,
        channel,
        annual_spend,
        annual_revenue,
        annual_orders,
        annual_new_customers,
        annual_roas,
        annual_cac,
        LAG(annual_roas) OVER (
            PARTITION BY channel
            ORDER BY year
        )                                   AS prev_year_roas,
        LAG(annual_cac) OVER (
            PARTITION BY channel
            ORDER BY year
        )                                   AS prev_year_cac,
        LAG(annual_spend) OVER (
            PARTITION BY channel
            ORDER BY year
        )                                   AS prev_year_spend
    FROM annual_roas
),
roas_change AS (
    -- Step 3: Calculate YoY change and rank
    SELECT
        year,
        channel,
        annual_spend,
        annual_revenue,
        annual_orders,
        annual_roas,
        annual_cac,
        prev_year_roas,
        ROUND(
            (annual_roas - prev_year_roas) / NULLIF(prev_year_roas, 0) * 100, 1
        )                                   AS roas_yoy_change_pct,
        ROUND(
            (annual_cac - prev_year_cac) / NULLIF(prev_year_cac, 0) * 100, 1
        )                                   AS cac_yoy_change_pct,
        ROUND(
            (annual_spend - prev_year_spend) / NULLIF(prev_year_spend, 0) * 100, 1
        )                                   AS spend_yoy_growth_pct,
        -- Rank channels by ROAS improvement within each year
        DENSE_RANK() OVER (
            PARTITION BY year
            ORDER BY annual_roas DESC
        )                                   AS roas_rank_in_year
    FROM roas_yoy
)
SELECT
    year,
    channel,
    ROUND(annual_spend / 1000, 1)           AS annual_spend_k,
    ROUND(annual_revenue / 1000, 1)         AS annual_revenue_k,
    annual_roas,
    prev_year_roas,
    roas_yoy_change_pct,
    cac_yoy_change_pct,
    spend_yoy_growth_pct,
    roas_rank_in_year,
    -- Trend label for dashboard display
    CASE
        WHEN roas_yoy_change_pct IS NULL    THEN 'Baseline Year'
        WHEN roas_yoy_change_pct >  5       THEN 'Improving (+)'
        WHEN roas_yoy_change_pct < -5       THEN 'Declining (-)'
        ELSE 'Stable'
    END                                     AS roas_trend
FROM roas_change
ORDER BY channel, year;
