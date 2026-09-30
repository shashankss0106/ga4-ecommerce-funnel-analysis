-- 04_weekly_trend.sql | Weekly sessions, purchases, conversion rate. Save result as weekly.csv
-- Note: 2020-11-01 is a Sunday, so the first week (starting 2020-10-26) has only 1 day. Exclude it in Power BI.
SELECT
  DATE_TRUNC(DATE(TIMESTAMP_MICROS(session_start_ts)), WEEK(MONDAY)) AS week_start,
  COUNT(*)                                   AS sessions,
  COUNTIF(n_purchases > 0)                   AS purchases,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(n_purchases > 0), COUNT(*)), 2) AS pct_session_to_purchase
FROM `starlit-glider-510218-m3.ga4_project.ga4_sessions`
GROUP BY week_start
ORDER BY week_start;
