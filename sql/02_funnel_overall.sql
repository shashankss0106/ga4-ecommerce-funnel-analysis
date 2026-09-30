-- 02_funnel_overall.sql | Overall funnel: session -> viewed item -> added to cart -> checkout -> purchase
-- Source: table built in Part C (ga4_sessions). One row in, one row out. Save result as overall.csv
SELECT
  COUNT(*)                          AS sessions,
  COUNTIF(viewed_item)              AS viewed_item,
  COUNTIF(added_to_cart)            AS added_to_cart,
  COUNTIF(began_checkout)           AS began_checkout,
  COUNTIF(n_purchases > 0)          AS purchased,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(viewed_item), COUNT(*)), 2)                        AS pct_session_to_view,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(added_to_cart), COUNTIF(viewed_item)), 2)          AS pct_view_to_cart,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(began_checkout), COUNTIF(added_to_cart)), 2)       AS pct_cart_to_checkout,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(n_purchases > 0), COUNTIF(began_checkout)), 2)     AS pct_checkout_to_purchase,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(n_purchases > 0), COUNT(*)), 2)                    AS pct_session_to_purchase,
  -- data-quality flag: purchases with no recorded begin_checkout event (steps are not strictly ordered)
  COUNTIF(n_purchases > 0 AND NOT began_checkout)                                    AS purchases_without_checkout_event
FROM `starlit-glider-510218-m3.ga4_project.ga4_sessions`
WHERE session_number IS NOT NULL;
