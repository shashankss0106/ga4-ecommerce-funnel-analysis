-- 03_funnel_by_segment.sql | Same funnel split by channel, device and new vs returning users.
-- Long format (dimension, segment) so one Power BI slicer can switch between them. Save result as segments.csv
WITH s AS (
  SELECT channel, device_category,
         IF(session_number > 1, 'Returning', 'New') AS user_type,
         viewed_item, added_to_cart, began_checkout, (n_purchases > 0) AS purchased
  FROM `starlit-glider-510218-m3.ga4_project.ga4_sessions`
  WHERE session_number IS NOT NULL
),
agg AS (
  SELECT 'Channel' AS dimension, channel AS segment, COUNT(*) AS sessions, COUNTIF(viewed_item) AS viewed_item,
         COUNTIF(added_to_cart) AS added_to_cart, COUNTIF(began_checkout) AS began_checkout, COUNTIF(purchased) AS purchased
  FROM s GROUP BY segment
  UNION ALL
  SELECT 'Device', device_category, COUNT(*), COUNTIF(viewed_item), COUNTIF(added_to_cart), COUNTIF(began_checkout), COUNTIF(purchased)
  FROM s GROUP BY device_category
  UNION ALL
  SELECT 'User type', user_type, COUNT(*), COUNTIF(viewed_item), COUNTIF(added_to_cart), COUNTIF(began_checkout), COUNTIF(purchased)
  FROM s GROUP BY user_type
)
SELECT *,
  ROUND(100 * SAFE_DIVIDE(viewed_item, sessions), 2)         AS pct_session_to_view,
  ROUND(100 * SAFE_DIVIDE(added_to_cart, viewed_item), 2)    AS pct_view_to_cart,
  ROUND(100 * SAFE_DIVIDE(began_checkout, added_to_cart), 2) AS pct_cart_to_checkout,
  ROUND(100 * SAFE_DIVIDE(purchased, began_checkout), 2)     AS pct_checkout_to_purchase,
  ROUND(100 * SAFE_DIVIDE(purchased, sessions), 2)           AS pct_session_to_purchase
FROM agg
ORDER BY dimension, sessions DESC;
