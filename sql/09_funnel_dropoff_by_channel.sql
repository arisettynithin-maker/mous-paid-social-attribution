/*
================================================================================
FILE:    09_funnel_dropoff_by_channel.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Where in the funnel (Impression -> Click -> Order) does each channel
  lose the most users? Which channel has the best end-to-end funnel efficiency?

WHY THIS MATTERS:
  Funnel drop-off analysis identifies where to prioritise optimisation effort.
  A high impression-to-click drop-off = weak creative or poor targeting.
  A high click-to-order drop-off = landing page, price, or product-fit issues.

SQL CONCEPTS DEMONSTRATED:
  - Multi-stage CTE chain for funnel modelling
  - LEAD() window function (showing next funnel stage conversion)
  - Percentage drop-off calculations at each funnel step
  - CASE WHEN for funnel stage labelling
  - Nested CTEs for readable multi-step logic
================================================================================
*/

WITH funnel_base AS (
    -- Step 1: Aggregate full-funnel metrics per channel
    SELECT
        channel,
        SUM(impressions)    AS total_impressions,
        SUM(clicks)         AS total_clicks,
        SUM(orders)         AS total_orders,
        SUM(new_customers)  AS total_new_customers
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY channel
),
funnel_rates AS (
    -- Step 2: Calculate conversion at each funnel stage
    SELECT
        channel,
        total_impressions,
        total_clicks,
        total_orders,
        total_new_customers,
        -- Stage 1: Impression -> Click (CTR)
        ROUND(
            CAST(total_clicks AS NUMERIC) / NULLIF(total_impressions, 0) * 100, 3
        )                   AS impression_to_click_pct,
        -- Stage 2: Click -> Order
        ROUND(
            CAST(total_orders AS NUMERIC) / NULLIF(total_clicks, 0) * 100, 3
        )                   AS click_to_order_pct,
        -- Stage 3: Order -> New Customer (new vs all orders)
        ROUND(
            CAST(total_new_customers AS NUMERIC) / NULLIF(total_orders, 0) * 100, 1
        )                   AS order_to_new_customer_pct,
        -- Full funnel: Impression -> Order
        ROUND(
            CAST(total_orders AS NUMERIC) / NULLIF(total_impressions, 0) * 100, 5
        )                   AS full_funnel_conversion_pct
    FROM funnel_base
),
funnel_dropoff AS (
    -- Step 3: Calculate drop-off at each stage
    SELECT
        channel,
        total_impressions,
        total_clicks,
        total_orders,
        impression_to_click_pct,
        click_to_order_pct,
        order_to_new_customer_pct,
        full_funnel_conversion_pct,
        -- Drop-off volumes
        total_impressions - total_clicks    AS dropped_at_click,
        total_clicks - total_orders         AS dropped_at_order,
        -- % of original impressions lost at each stage
        ROUND(
            (total_impressions - total_clicks)::NUMERIC / total_impressions * 100, 1
        )                                   AS pct_lost_at_click_stage,
        ROUND(
            (total_clicks - total_orders)::NUMERIC / total_impressions * 100, 1
        )                                   AS pct_lost_at_order_stage,
        -- Identify biggest funnel bottleneck
        CASE
            WHEN CAST(total_clicks AS NUMERIC) / NULLIF(total_impressions, 0) < 0.01
                THEN 'Creative/Targeting weak — fix impression->click'
            WHEN CAST(total_orders AS NUMERIC) / NULLIF(total_clicks, 0) < 0.01
                THEN 'Landing page/product weak — fix click->order'
            ELSE 'Funnel healthy'
        END                                 AS bottleneck_diagnosis
    FROM funnel_rates
)
SELECT
    channel,
    total_impressions,
    total_clicks,
    total_orders,
    impression_to_click_pct     AS ctr_pct,
    click_to_order_pct          AS cvr_pct,
    full_funnel_conversion_pct  AS end_to_end_cvr_pct,
    dropped_at_click,
    dropped_at_order,
    pct_lost_at_click_stage,
    pct_lost_at_order_stage,
    bottleneck_diagnosis
FROM funnel_dropoff
ORDER BY full_funnel_conversion_pct DESC;

-- ── FUNNEL by CAMPAIGN TYPE: Does Retargeting improve CVR? ────────────────
SELECT
    channel,
    campaign_type,
    SUM(impressions)     AS impressions,
    SUM(clicks)          AS clicks,
    SUM(orders)          AS orders,
    ROUND(SUM(clicks)::NUMERIC  / NULLIF(SUM(impressions), 0) * 100, 3) AS ctr_pct,
    ROUND(SUM(orders)::NUMERIC  / NULLIF(SUM(clicks),      0) * 100, 3) AS cvr_pct,
    ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 2)             AS roas
FROM marketing_performance
WHERE channel != 'Organic'
GROUP BY channel, campaign_type
ORDER BY channel, cvr_pct DESC;
