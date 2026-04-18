/*
================================================================================
FILE:    02_first_purchase_by_channel.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Which channel drives the highest new customer acquisition each month,
  and how does that rank change month-to-month across the 3-year period?

WHY THIS MATTERS:
  New customer volume by channel tells us which channel is growing the brand's
  addressable customer base. Channels with consistently high first-purchase
  volume should receive higher budget allocation for Prospecting campaigns.

SQL CONCEPTS DEMONSTRATED:
  - DATE_TRUNC to bucket daily data into monthly periods
  - RANK() window function OVER (PARTITION BY month ORDER BY new_customers DESC)
  - Window functions for ranking within time periods
  - CTE (Common Table Expression) to separate aggregation from ranking
  - EXTRACT for year/month components
================================================================================
*/

WITH monthly_new_customers AS (
    -- Step 1: Aggregate new customers per channel per month
    SELECT
        DATE_TRUNC('month', date::DATE)   AS month_start,
        EXTRACT(YEAR  FROM date::DATE)    AS year,
        EXTRACT(MONTH FROM date::DATE)    AS month_num,
        channel,
        SUM(new_customers)                AS total_new_customers,
        SUM(spend_gbp)                    AS total_spend,
        ROUND(SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2) AS cac_gbp
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY
        DATE_TRUNC('month', date::DATE),
        EXTRACT(YEAR  FROM date::DATE),
        EXTRACT(MONTH FROM date::DATE),
        channel
),
ranked AS (
    -- Step 2: Rank channels by new customer volume within each month
    SELECT
        month_start,
        year,
        month_num,
        channel,
        total_new_customers,
        total_spend,
        cac_gbp,
        RANK() OVER (
            PARTITION BY month_start
            ORDER BY total_new_customers DESC
        ) AS rank_in_month
    FROM monthly_new_customers
)
SELECT
    month_start,
    channel,
    total_new_customers,
    total_spend,
    cac_gbp,
    rank_in_month,
    -- Flag when a channel has held #1 spot for 3+ consecutive months
    CASE WHEN rank_in_month = 1 THEN 'TOP CHANNEL' ELSE '' END AS top_channel_flag
FROM ranked
WHERE rank_in_month <= 3    -- Top 3 channels per month
ORDER BY month_start ASC, rank_in_month ASC;

-- ── SUMMARY: How often each channel wins #1 ──────────────────────────────
WITH monthly_new_customers AS (
    SELECT
        DATE_TRUNC('month', date::DATE) AS month_start,
        channel,
        SUM(new_customers)              AS total_new_customers
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY DATE_TRUNC('month', date::DATE), channel
),
ranked AS (
    SELECT
        month_start,
        channel,
        total_new_customers,
        RANK() OVER (PARTITION BY month_start ORDER BY total_new_customers DESC) AS rnk
    FROM monthly_new_customers
)
SELECT
    channel,
    COUNT(*) FILTER (WHERE rnk = 1) AS months_at_rank_1,
    COUNT(*) FILTER (WHERE rnk = 2) AS months_at_rank_2,
    COUNT(*) FILTER (WHERE rnk = 3) AS months_at_rank_3,
    ROUND(AVG(total_new_customers), 0) AS avg_monthly_new_customers
FROM ranked
GROUP BY channel
ORDER BY months_at_rank_1 DESC;
