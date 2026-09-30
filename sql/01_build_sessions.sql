-- 01_build_sessions.sql  |  One row per session (user_pseudo_id + ga_session_id).
-- Project/dataset below is my own BigQuery sandbox project; change it to yours before running.
--
-- WHY this design: traffic_source.medium in GA4 export is the user's FIRST-touch source and
-- is identical on every session of that user, so it cannot support multi-touch analysis.
-- Instead we derive a SESSION-level channel from (1) event_params source/medium if present,
-- else (2) UTM/gclid in the session's landing-page URL, else (3) the landing-page referrer.
-- Direct = no campaign signal and no external referrer.

CREATE OR REPLACE TABLE `starlit-glider-510218-m3.ga4_project.ga4_sessions` AS
WITH base AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')     AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')  AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_referrer')  AS page_referrer,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source')         AS param_source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium')         AS param_medium,
    event_timestamp, event_name,
    device.category AS device_category,
    geo.country AS country,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions_core AS (
  SELECT
    user_pseudo_id, session_id,
    MIN(event_timestamp)                        AS session_start_ts,   -- microseconds
    MAX(session_number)                         AS session_number,
    ANY_VALUE(device_category)                  AS device_category,
    ANY_VALUE(country)                          AS country,
    COUNTIF(event_name = 'page_view')           AS page_views,
    COUNTIF(event_name = 'view_item')    > 0    AS viewed_item,
    COUNTIF(event_name = 'add_to_cart')  > 0    AS added_to_cart,
    COUNTIF(event_name = 'begin_checkout') > 0  AS began_checkout,
    -- first non-null source/medium params in the session (NULL if dataset lacks them)
    ARRAY_AGG(param_source IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS param_source,
    ARRAY_AGG(param_medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS param_medium
  FROM base
  WHERE session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_id
),
landing AS (   -- landing page + referrer = earliest page_view of the session
  SELECT user_pseudo_id, session_id,
         ARRAY_AGG(STRUCT(page_location, page_referrer) ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS l
  FROM base
  WHERE event_name = 'page_view' AND page_location IS NOT NULL AND session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_id
),
purch AS (     -- de-duplicated transactions (one row per transaction_id)
  SELECT user_pseudo_id, session_id, transaction_id, purchase_revenue
  FROM base
  WHERE event_name = 'purchase' AND session_id IS NOT NULL
    AND transaction_id IS NOT NULL AND transaction_id != '(not set)'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
purch_sess AS (
  SELECT user_pseudo_id, session_id,
         COUNT(*) AS n_purchases, SUM(IFNULL(purchase_revenue, 0)) AS revenue
  FROM purch GROUP BY user_pseudo_id, session_id
),
signals AS (
  SELECT s.*,
    LOWER(COALESCE(s.param_medium, REGEXP_EXTRACT(l.l.page_location, r'[?&]utm_medium=([^&#]+)'))) AS medium_sig,
    LOWER(COALESCE(s.param_source, REGEXP_EXTRACT(l.l.page_location, r'[?&]utm_source=([^&#]+)'))) AS source_sig,
    REGEXP_CONTAINS(IFNULL(l.l.page_location, ''), r'[?&]gclid=') AS has_gclid,
    LOWER(NET.HOST(l.l.page_referrer)) AS ref_host
  FROM sessions_core s
  LEFT JOIN landing l USING (user_pseudo_id, session_id)
)
SELECT
  g.user_pseudo_id, g.session_id, g.session_start_ts, g.session_number,
  g.device_category, g.country, g.page_views, g.viewed_item, g.added_to_cart, g.began_checkout,
  CASE
    WHEN g.has_gclid OR REGEXP_CONTAINS(IFNULL(g.medium_sig,''), r'^(cpc|ppc|paidsearch|paid_search)$') THEN 'Paid Search'
    WHEN REGEXP_CONTAINS(IFNULL(g.medium_sig,''), r'display|banner|cpm')                             THEN 'Display'
    WHEN REGEXP_CONTAINS(IFNULL(g.medium_sig,''), r'^e-?mail$')                                       THEN 'Email'
    WHEN REGEXP_CONTAINS(IFNULL(g.medium_sig,''), r'social|paid_social')
      OR REGEXP_CONTAINS(IFNULL(g.ref_host,''), r'(facebook|instagram|twitter|t\.co|linkedin|pinterest|reddit|youtube)\.') THEN 'Social'
    WHEN REGEXP_CONTAINS(IFNULL(g.medium_sig,''), r'^organic$')
      OR REGEXP_CONTAINS(IFNULL(g.ref_host,''), r'(^|\.)(google|bing|yahoo|duckduckgo|baidu|ecosia|yandex)\.')
      THEN 'Organic Search'
    WHEN g.ref_host IS NOT NULL AND g.ref_host != '' AND NOT REGEXP_CONTAINS(g.ref_host, r'googlemerchandisestore') THEN 'Referral'
    ELSE 'Direct'
  END AS channel,
  IFNULL(p.n_purchases, 0) AS n_purchases,
  IFNULL(p.revenue, 0)     AS revenue
FROM signals g
LEFT JOIN purch_sess p USING (user_pseudo_id, session_id);
-- NOTE: the store's own host is excluded from Referral so internal navigation is not a channel.
-- NOTE: the 'Organic Search' regex is checked AFTER Paid Search, so gclid sessions are never organic.
