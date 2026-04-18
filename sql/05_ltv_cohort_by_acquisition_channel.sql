/*
================================================================================
FILE:    05_ltv_cohort_by_acquisition_channel.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  What is the 90-day revenue contribution (proxy LTV) by acquisition channel
  cohort? Which channel acquires customers who generate most value in the
  first 90 days post-acquisition?

WHY THIS MATTERS:
  LTV/CAC ratio is the core D2C health metric. A channel with 2x ROAS but
  3x 90-day LTV is significantly more valuable than a 4x ROAS channel with
  1.2x 90-day LTV. This query enables LTV-weighted budget allocation.

SQL CONCEPTS DEMONSTRATED:
  - Multi-step CTE chain (3 CTEs in sequence)
  - Cohort logic using acquisition month as the grouping key
  - Date arithmetic (acquisition_date + INTERVAL '90 days')
  - LEFT JOIN for cohort revenue lookup
  - Ratio of LTV to CAC as a derived metric
================================================================================
*/

-- NOTE: This query models 90-day LTV using the assumption that customers
-- acquired in month M generate revenue proportional to their channel's
-- repeat rate in the following 90 days.
-- In production, this would join to an orders fact table by customer_id.

WITH acquisition_cohorts AS (
    -- Step 1: Identify monthly new customer cohorts per channel
    SELECT
        DATE_TRUNC('month', date::DATE)     AS cohort_month,
        channel,
        SUM(new_customers)                  AS cohort_size,
        ROUND(SUM(spend_gbp), 2)            AS cohort_spend,
        ROUND(SUM(spend_gbp)
              / NULLIF(SUM(new_customers), 0), 2) AS cohort_cac
    FROM marketing_performance
    WHERE channel != 'Organic'
      AND new_customers > 0
    GROUP BY
        DATE_TRUNC('month', date::DATE),
        channel
),
next_90_days_revenue AS (
    -- Step 2: Capture revenue in the 90-day window after each cohort month
    SELECT
        DATE_TRUNC('month', date::DATE)              AS revenue_month,
        channel,
        SUM(revenue_gbp)                             AS period_revenue,
        SUM(returning_customers)                     AS returning_count
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY
        DATE_TRUNC('month', date::DATE),
        channel
),
ltv_cohort AS (
    -- Step 3: Join cohort to 90-day revenue window (cohort_month + 1 to +3 months)
    SELECT
        ac.cohort_month,
        ac.channel,
        ac.cohort_size,
        ac.cohort_spend,
        ac.cohort_cac,
        COALESCE(SUM(nr.period_revenue), 0)   AS revenue_90d,
        COALESCE(SUM(nr.returning_count), 0)  AS returning_90d
    FROM acquisition_cohorts ac
    LEFT JOIN next_90_days_revenue nr
        ON  nr.channel = ac.channel
        AND nr.revenue_month > ac.cohort_month
        AND nr.revenue_month <= ac.cohort_month + INTERVAL '3 months'
    GROUP BY
        ac.cohort_month,
        ac.channel,
        ac.cohort_size,
        ac.cohort_spend,
        ac.cohort_cac
)
SELECT
    cohort_month,
    channel,
    cohort_size,
    cohort_cac,
    ROUND(revenue_90d, 2)                                        AS revenue_90d_gbp,
    ROUND(revenue_90d / NULLIF(cohort_size, 0), 2)              AS ltv_90d_per_customer,
    ROUND(revenue_90d / NULLIF(cohort_spend, 0), 3)             AS ltv_roas_90d,
    returning_90d,
    ROUND(returning_90d::NUMERIC / NULLIF(cohort_size, 0) * 100, 1) AS return_rate_90d_pct,
    -- LTV/CAC ratio: >3x is excellent for a premium D2C brand
    ROUND(
        (revenue_90d / NULLIF(cohort_size, 0))
        / NULLIF(cohort_cac, 0),
        2
    )                                                            AS ltv_cac_ratio
FROM ltv_cohort
WHERE cohort_size > 0
ORDER BY cohort_month, channel;
