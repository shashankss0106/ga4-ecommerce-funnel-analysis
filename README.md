# GA4 E-commerce Funnel & Conversion Analysis

Where do online shoppers drop off between landing on a store and buying, and do traffic channel, device or
new-vs-returning status change that? Built on Google's public GA4 sample e-commerce dataset
(Google Merchandise Store, 1 Nov 2020 - 31 Jan 2021).

**Tools:** BigQuery SQL (CTEs, aggregation, conditional counts), Python (data checks), Power BI (dashboard).

## Key findings
Overall: **360,129 sessions -> 4,033 purchases (1.12% conversion)**.

| Funnel step | % of previous step continuing |
|---|---|
| Session -> viewed an item | 21.4% |
| Viewed item -> added to cart | 19.7% |
| Added to cart -> began checkout | 73.1% |
| Checkout -> purchase | 36.3% |

- **Biggest drop-off is view -> add to cart:** 80.3% of sessions that view a product never add it to the cart.
  After the cart, the largest leak is at checkout: 63.7% of checkouts do not finish in a purchase.
- **Returning users convert about 4.4x more than new users:** 2.56% vs 0.58% (new users are 261,238 of the sessions).
- **Organic Search converts best among the main channels (1.35%), Direct 1.04%, Paid Search lowest at 0.55%.**
  Paid Search has only 7,672 sessions (roughly 40 purchases), so treat that result with caution.
- **Device differences are small:** mobile 1.16%, desktop 1.10%, tablet 1.02%.
- **Highest weekly conversion** was the week of 2020-12-07 (1.91%).

## Suggested actions (hypotheses to test, not proven causes)
1. Test product-page changes (clearer price/availability, more prominent add-to-cart) to reduce the view -> cart leak.
2. Investigate checkout friction (63.7% of started checkouts are abandoned), e.g. shipping cost visibility, fewer form fields.
3. Test a first-visit hook for new users (e.g. email capture, returning-visit reminders), since they convert far less.

## Method
1. `sql/01_build_sessions.sql` builds one row per session (`user_pseudo_id` + `ga_session_id`) with device, new/returning
   (`ga_session_number > 1`), funnel flags (viewed item, add to cart, begin checkout), de-duplicated purchases and revenue,
   and a derived channel (UTM/gclid in landing URL, else landing-page referrer, else Direct).
2. `sql/02-04` compute the overall funnel, the funnel by channel/device/user type, and the weekly trend.
3. `python/funnel_check.py` verifies that channel, device and user-type tables each add up to the overall totals and
   prints the findings above.
4. Power BI dashboard: funnel chart, conversion by segment, weekly trend (see `dashboard/`).

A session counts at a step if that event occurred in the session (steps are not forced into order). In this run every
purchase had a checkout event.

## Limitations
- Three months of data from one store, including the holiday period; sample is obfuscated.
- Channel is derived from landing-page UTM/referrer signals; Direct is a catch-all (69% of sessions here), and all other
  channels together are only 197 sessions, so channel results are indicative only.
- Users are cookie-based, so one person on two devices counts as two users.
- Differences between segments are associations, not proof of cause (e.g. returning users are more likely to be intent-driven).

## Run it yourself
1. Create a free BigQuery sandbox project and a dataset named `ga4_project` (US location).
2. Change the project ID in the SQL files, run `sql/01_build_sessions.sql`, then `02` to `04`.
3. Save each result as CSV (`overall.csv`, `segments.csv`, `weekly.csv`) into `results/`.
4. `python python/funnel_check.py results/overall.csv results/segments.csv results/weekly.csv` (standard library only).

<!-- After building the Power BI page: save a screenshot as dashboard/dashboard.png and add:
![Dashboard](dashboard/dashboard.png) -->
