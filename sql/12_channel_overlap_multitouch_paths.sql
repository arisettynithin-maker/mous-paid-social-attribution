/*
================================================================================
FILE:    12_channel_overlap_multitouch_paths.sql
PROJECT: Mous Paid Social ROAS Attribution Model
================================================================================
BUSINESS QUESTION:
  Which channel combinations appear most frequently in multi-touch customer
  journeys? Are there high-revenue paths that start with TikTok/YouTube
  but convert via Google Search?

WHY THIS MATTERS:
  Understanding which channel pairs co-occur in journeys is critical for
  budget planning. If 40% of high-value orders involve TikTok early in
  the path and Google Search at conversion, cutting TikTok would collapse
  Google Search revenue too.

SQL CONCEPTS DEMONSTRATED:
  - Self-join pattern to find co-occurring channels in same time window
  - EXISTS subquery (semi-join) to filter rows
  - Anti-join pattern using NOT EXISTS
  - STRING_AGG to concatenate channel paths into readable strings
  - Journey simulation using date-window proximity joins
================================================================================
*/

-- NOTE: In production, this query would operate on a customer-level touchpoint
-- table (customer_id, touchpoint_date, channel). Here we simulate using
-- the daily aggregated data as a proxy for journey co-occurrence patterns.

WITH daily_active_channels AS (
    -- Step 1: Which channels were active (had spend) on each date?
    SELECT
        date,
        STRING_AGG(DISTINCT channel, ' > ' ORDER BY channel) AS active_channel_path,
        COUNT(DISTINCT channel)                               AS channels_active,
        SUM(spend_gbp)                                        AS total_daily_spend,
        SUM(revenue_gbp)                                      AS total_daily_revenue,
        SUM(orders)                                           AS total_daily_orders
    FROM marketing_performance
    WHERE channel != 'Organic'
      AND spend_gbp > 0
    GROUP BY date
),
channel_pair_cooccurrence AS (
    -- Step 2: Self-join to find channels that were active on the SAME day
    -- (proxy for same-day multi-touch journey)
    SELECT
        a.channel                                             AS channel_a,
        b.channel                                             AS channel_b,
        COUNT(*)                                              AS days_cooccurred,
        ROUND(SUM(a.spend_gbp + b.spend_gbp), 0)            AS combined_spend,
        ROUND(SUM(a.revenue_gbp + b.revenue_gbp), 0)        AS combined_revenue,
        ROUND(
            SUM(a.revenue_gbp + b.revenue_gbp)
            / NULLIF(SUM(a.spend_gbp + b.spend_gbp), 0), 3
        )                                                     AS combined_roas
    FROM marketing_performance a
    JOIN marketing_performance b
        ON  a.date    = b.date
        AND a.channel < b.channel           -- Avoid duplicates (A,B) and (B,A)
        AND a.channel != 'Organic'
        AND b.channel != 'Organic'
        AND a.spend_gbp > 0
        AND b.spend_gbp > 0
    GROUP BY a.channel, b.channel
    HAVING COUNT(*) > 30                    -- Only meaningful co-occurrences
),
top_paths AS (
    -- Step 3: Rank channel pairs by revenue contribution
    SELECT
        channel_a,
        channel_b,
        channel_a || ' + ' || channel_b     AS channel_pair,
        days_cooccurred,
        combined_spend,
        combined_revenue,
        combined_roas,
        RANK() OVER (ORDER BY combined_revenue DESC) AS revenue_rank
    FROM channel_pair_cooccurrence
)
SELECT
    channel_pair,
    days_cooccurred,
    combined_spend,
    combined_revenue,
    combined_roas,
    revenue_rank
FROM top_paths
ORDER BY revenue_rank;

-- ── ANTI-JOIN: Days when TikTok ran WITHOUT Google Search ─────────────────
-- (reveals isolated TikTok spend with no harvest channel to convert traffic)
SELECT
    mp.date,
    mp.channel,
    SUM(mp.spend_gbp)   AS spend,
    SUM(mp.revenue_gbp) AS revenue,
    SUM(mp.orders)      AS orders,
    ROUND(SUM(mp.revenue_gbp) / NULLIF(SUM(mp.spend_gbp), 0), 3) AS roas
FROM marketing_performance mp
WHERE mp.channel = 'TikTok'
  AND mp.spend_gbp > 0
  AND NOT EXISTS (
    -- Anti-join: exclude dates where Google Search was also active
    SELECT 1
    FROM marketing_performance gs
    WHERE gs.date    = mp.date
      AND gs.channel = 'Google_Search'
      AND gs.spend_gbp > 0
  )
GROUP BY mp.date, mp.channel
ORDER BY mp.date;

-- ── STRING_AGG: Most common 3-channel journey paths by month ──────────────
SELECT
    DATE_TRUNC('month', date::DATE)   AS month,
    STRING_AGG(
        DISTINCT channel,
        ' > '
        ORDER BY channel
    )                                  AS channel_mix,
    COUNT(DISTINCT date)               AS days_in_month,
    ROUND(SUM(spend_gbp), 0)          AS monthly_spend,
    ROUND(SUM(revenue_gbp), 0)        AS monthly_revenue
FROM marketing_performance
WHERE channel != 'Organic'
  AND spend_gbp > 0
GROUP BY DATE_TRUNC('month', date::DATE)
ORDER BY month;
