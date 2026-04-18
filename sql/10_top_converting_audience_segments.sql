/*
================================================================================
FILE:    10_top_converting_audience_segments.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Which campaign_type + channel combination delivers the best conversion
  efficiency and ROAS? Where should the next £10k of incremental budget go?

WHY THIS MATTERS:
  Not all spend within a channel performs equally. A Retargeting campaign on
  Meta behaves very differently from a Prospecting campaign on TikTok.
  This query enables granular budget allocation decisions at the campaign level.

SQL CONCEPTS DEMONSTRATED:
  - Multi-column GROUP BY (channel + campaign_type cross-tabulation)
  - RANK() OVER PARTITION — ranking within each channel independently
  - Correlated subquery to compare segment performance vs channel average
  - Composite efficiency score calculation
  - Filtering via inner subquery
================================================================================
*/

WITH segment_metrics AS (
    -- Step 1: Performance by channel x campaign_type segment
    SELECT
        channel,
        campaign_type,
        COUNT(*)                                                         AS row_count,
        SUM(impressions)                                                 AS total_impressions,
        SUM(clicks)                                                      AS total_clicks,
        SUM(spend_gbp)                                                   AS total_spend,
        SUM(revenue_gbp)                                                 AS total_revenue,
        SUM(orders)                                                      AS total_orders,
        SUM(new_customers)                                               AS total_new_customers,
        ROUND(SUM(clicks)::NUMERIC / NULLIF(SUM(impressions), 0) * 100, 3) AS ctr_pct,
        ROUND(SUM(orders)::NUMERIC / NULLIF(SUM(clicks), 0) * 100, 3)   AS cvr_pct,
        ROUND(SUM(revenue_gbp) / NULLIF(SUM(spend_gbp), 0), 3)         AS roas,
        ROUND(SUM(spend_gbp) / NULLIF(SUM(orders), 0), 2)              AS cpo_gbp,
        ROUND(SUM(spend_gbp) / NULLIF(SUM(new_customers), 0), 2)       AS cac_gbp
    FROM marketing_performance
    WHERE channel != 'Organic'
    GROUP BY channel, campaign_type
),
ranked_segments AS (
    -- Step 2: Rank each campaign_type within its channel by ROAS
    SELECT
        sm.*,
        RANK() OVER (
            PARTITION BY channel
            ORDER BY roas DESC
        )                                                                AS roas_rank_within_channel,
        RANK() OVER (
            ORDER BY roas DESC
        )                                                                AS overall_roas_rank,
        -- Composite efficiency: weighted ROAS + CVR + CAC efficiency
        ROUND(
            (roas * 0.5)
            + (cvr_pct * 10 * 0.3)
            + (CASE WHEN cac_gbp > 0 THEN 100 / cac_gbp * 0.2 ELSE 0 END),
            2
        )                                                                AS composite_efficiency_score
    FROM segment_metrics
),
channel_avg_roas AS (
    -- Step 3: Channel-level average ROAS for correlated comparison
    SELECT
        channel,
        AVG(roas) AS channel_avg_roas
    FROM segment_metrics
    GROUP BY channel
)
SELECT
    rs.channel,
    rs.campaign_type,
    rs.total_spend,
    rs.total_revenue,
    rs.roas,
    rs.ctr_pct,
    rs.cvr_pct,
    rs.cpo_gbp,
    rs.cac_gbp,
    rs.roas_rank_within_channel,
    rs.overall_roas_rank,
    rs.composite_efficiency_score,
    -- Correlated comparison: is this segment above or below channel average?
    ROUND(ca.channel_avg_roas, 3)                                        AS channel_avg_roas,
    ROUND(rs.roas - ca.channel_avg_roas, 3)                              AS roas_vs_channel_avg,
    CASE
        WHEN rs.roas > ca.channel_avg_roas * 1.10 THEN 'Scale Up'
        WHEN rs.roas < ca.channel_avg_roas * 0.90 THEN 'Reduce or Pause'
        ELSE 'Maintain'
    END                                                                  AS budget_recommendation
FROM ranked_segments rs
JOIN channel_avg_roas ca ON rs.channel = ca.channel
-- Correlated subquery: only show segments in the top 50% of their channel
WHERE rs.roas >= (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY roas)
    FROM segment_metrics s2
    WHERE s2.channel = rs.channel
)
ORDER BY composite_efficiency_score DESC;
