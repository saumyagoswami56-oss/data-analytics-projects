-- ============================================================
-- PART 4 — Business Question (single file, easy comments)
-- Q: If I launch a YouTube channel tomorrow, which category
--    (excluding Music & Entertainment) should I target to appear
--    in Top Trend? Will this work in every country?
--
-- My angle: I love fashion/shoes → aim for "Howto & Style".
-- This script shows the data (2024) to compare categories,
-- check country-by-country, and give proof for fashion.
-- ============================================================

USE DATABASE assignment_1;
USE SCHEMA PUBLIC;

-- -----------------------------------------
-- 0) Make a safe category name lookup table
--    (fills missing titles from the JSON file)
-- -----------------------------------------
CREATE OR REPLACE TEMP TABLE cat_map AS
SELECT
  COUNTRY,
  CATEGORYID::NUMBER AS CATEGORYID,
  MIN(CATEGORY_TITLE) AS CAT_TITLE
FROM table_youtube_category
GROUP BY 1,2;

-- ---------------------------------------------------
-- 1) Build a clean base table with good types + names
--    - day_dt: date for trending
--    - pub_dt: date video published
--    - CAT_TITLE: final category name (filled from cat_map if missing)
-- ---------------------------------------------------
CREATE OR REPLACE TEMP TABLE base_all AS
SELECT
  f.COUNTRY,
  TO_DATE(LEFT(f.TRENDING_DATE::STRING, 10)) AS day_dt,
  TO_DATE(LEFT(f.PUBLISHEDAT::STRING, 10))   AS pub_dt,
  f.VIDEO_ID,
  f.TITLE,
  f.CHANNELTITLE,
  f.CATEGORYID,
  COALESCE(f.CATEGORY_TITLE, cm.CAT_TITLE)   AS CAT_TITLE,
  TRY_TO_NUMBER(f.VIEW_COUNT)                AS VIEW_COUNT,
  TRY_TO_NUMBER(f.LIKES)                     AS LIKES,
  TRY_TO_NUMBER(f.COMMENT_COUNT)             AS COMMENT_COUNT
FROM table_youtube_final f
LEFT JOIN cat_map cm
  ON f.COUNTRY   = cm.COUNTRY
 AND f.CATEGORYID = cm.CATEGORYID;

-- --------------------------------------------
-- 2) Keep only NON Music/Entertainment for 2024
--    - remove by name and by common IDs (Music=10, Ent=24)
-- --------------------------------------------
CREATE OR REPLACE TEMP TABLE base_non_me AS
SELECT *
FROM base_all
WHERE CAT_TITLE IS NOT NULL
  AND YEAR(day_dt) = 2024
  AND NOT (
    UPPER(CAT_TITLE) IN ('MUSIC','ENTERTAINMENT')
    OR CATEGORYID IN (10, 24)
  );

-- --------------------------------------------
-- 3) Rank videos by views per (country, day)
--    - rk = 1 means daily winner for that country (non-M/E)
--    - this lets us talk about "who won the day"
-- --------------------------------------------
CREATE OR REPLACE TEMP TABLE daily_rank_non_me AS
SELECT
  COUNTRY, day_dt, pub_dt, VIDEO_ID, TITLE, CHANNELTITLE,
  CATEGORYID, CAT_TITLE, VIEW_COUNT, LIKES, COMMENT_COUNT,
  ROW_NUMBER() OVER (
    PARTITION BY COUNTRY, day_dt
    ORDER BY VIEW_COUNT DESC NULLS LAST, VIDEO_ID
  ) AS rk
FROM base_non_me;

-- --------------------------------------------
-- 4) Daily winners (non-M/E) for 2024
-- --------------------------------------------
CREATE OR REPLACE TEMP TABLE winners AS
SELECT *
FROM daily_rank_non_me
WHERE rk = 1;

-- =========================================================
-- A) CORE ANSWERS FOR THE BUSINESS QUESTION (simple outputs)
-- =========================================================

-- A1) GLOBAL RECOMMENDATION:
--     Which non-M/E category wins the most #1 days in 2024?
CREATE OR REPLACE TEMP TABLE global_pick AS
SELECT
  CAT_TITLE,
  COUNT(*) AS days_as_top_global
FROM winners
GROUP BY CAT_TITLE
ORDER BY days_as_top_global DESC, CAT_TITLE
LIMIT 1;

SELECT
  'GLOBAL_RECOMMENDATION (2024)' AS section,
  CAT_TITLE                      AS category,
  days_as_top_global             AS days_won
FROM global_pick;

-- A2) PORTABILITY:
--     For each country, % of days the global pick also wins
SELECT
  'PORTABILITY (share of 2024 days won by global pick)' AS section,
  w.COUNTRY                                             AS country,
  ROUND(
    100 * SUM(IFF(w.CAT_TITLE = (SELECT CAT_TITLE FROM global_pick), 1, 0))
        / NULLIF(COUNT(*), 0)
  , 2) AS pct_days_global_pick_wins
FROM winners w
GROUP BY w.COUNTRY
ORDER BY pct_days_global_pick_wins DESC, country;

-- A3) COUNTRY_BEST:
--     For each country, its own best non-M/E category in 2024
SELECT
  'COUNTRY_BEST (2024)' AS section,
  COUNTRY               AS country,
  CAT_TITLE             AS best_category,
  days_as_top           AS days_won
FROM (
  SELECT
    COUNTRY,
    CAT_TITLE,
    COUNT(*) AS days_as_top,
    ROW_NUMBER() OVER (
      PARTITION BY COUNTRY
      ORDER BY COUNT(*) DESC, CAT_TITLE
    ) AS r
  FROM winners
  GROUP BY COUNTRY, CAT_TITLE
)
WHERE r = 1
ORDER BY country;

-- ===================================================================
-- B) EXTRA EVIDENCE THAT "HOWTO & STYLE" (FASHION) IS A GOOD START
--     (even if Gaming is often #1 globally)
-- ===================================================================

-- B1) Table of all winning categories in 2024 (non-M/E) by days won
SELECT
  CAT_TITLE,
  CATEGORYID,
  COUNT(*) AS days_as_top_global
FROM winners
GROUP BY CAT_TITLE, CATEGORYID
ORDER BY days_as_top_global DESC, CAT_TITLE;

-- B2) Howto & Style vs Gaming: who wins more days by country (2024)
WITH cat_win AS (
  SELECT
    COUNTRY,
    SUM(IFF(UPPER(CAT_TITLE) LIKE 'GAMING%' OR CATEGORYID = 20, 1, 0)) AS gaming_wins,
    SUM(IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%'  OR CATEGORYID = 26, 1, 0)) AS howto_wins
  FROM winners
  GROUP BY COUNTRY
)
SELECT
  COUNTRY,
  howto_wins,
  gaming_wins,
  (howto_wins - gaming_wins) AS diff_howto_minus_gaming
FROM cat_win
ORDER BY diff_howto_minus_gaming DESC, howto_wins DESC, COUNTRY;

-- B3) Per-country share: % of 2024 days where Howto & Style is #1 (non-M/E)
SELECT
  COUNTRY,
  ROUND(100 * AVG(IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26, 1, 0)), 2)
    AS pct_days_howto_wins
FROM winners
GROUP BY COUNTRY
ORDER BY pct_days_howto_wins DESC, COUNTRY;

-- B4) Top-10 presence: % of 2024 days with ANY Howto & Style in the top-10
WITH top10 AS (
  SELECT * FROM daily_rank_non_me WHERE rk <= 10
),
daily_any AS (
  SELECT COUNTRY, day_dt,
         MAX(IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26, 1, 0)) AS any_howto_in_top10
  FROM top10
  GROUP BY COUNTRY, day_dt
)
SELECT
  COUNTRY,
  ROUND(100 * AVG(any_howto_in_top10), 2) AS pct_days_with_howto_in_top10
FROM daily_any
GROUP BY COUNTRY
ORDER BY pct_days_with_howto_in_top10 DESC, COUNTRY;

-- B5) Engagement (top-10 only): likes% and comments per 1k views (Howto vs Gaming)
WITH top10 AS (
  SELECT * FROM daily_rank_non_me WHERE rk <= 10
),
scored AS (
  SELECT
    CASE
      WHEN (UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26) THEN 'HOWTO_STYLE'
      WHEN (UPPER(CAT_TITLE) LIKE 'GAMING%' OR CATEGORYID = 20) THEN 'GAMING'
      ELSE 'OTHER'
    END AS grp,
    LIKES / NULLIF(VIEW_COUNT,0) * 100          AS likes_pct,
    COMMENT_COUNT * 1000 / NULLIF(VIEW_COUNT,0) AS comments_per_1000
  FROM top10
)
SELECT
  grp,
  ROUND(AVG(likes_pct), 2)          AS avg_likes_pct,
  ROUND(MEDIAN(likes_pct), 2)       AS med_likes_pct,
  ROUND(AVG(comments_per_1000), 2)  AS avg_comments_per_1000,
  ROUND(MEDIAN(comments_per_1000),2)AS med_comments_per_1000
FROM scored
WHERE grp IN ('HOWTO_STYLE','GAMING')
GROUP BY grp
ORDER BY grp;

-- B6) Monthly trend in 2024: share of #1 days won by Howto & Style
SELECT
  DATE_TRUNC('month', day_dt) AS year_month,
  COUNT(*) AS total_days,
  SUM(IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26, 1, 0)) AS howto_days,
  ROUND(100 * SUM(IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26, 1, 0))
           / NULLIF(COUNT(*),0), 2) AS howto_share_pct
FROM winners
GROUP BY 1
ORDER BY 1;

-- B7) Freshness: median days from publish → trending for winners (Howto vs Gaming)
WITH w AS (
  SELECT
    CASE
      WHEN (UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26) THEN 'HOWTO_STYLE'
      WHEN (UPPER(CAT_TITLE) LIKE 'GAMING%' OR CATEGORYID = 20) THEN 'GAMING'
      ELSE 'OTHER'
    END AS grp,
    DATEDIFF('day', pub_dt, day_dt) AS days_to_trend
  FROM winners
  WHERE pub_dt IS NOT NULL
)
SELECT
  grp,
  MEDIAN(days_to_trend) AS med_days_to_trend
FROM w
WHERE grp IN ('HOWTO_STYLE','GAMING')
GROUP BY grp
ORDER BY grp;

-- B8) Creator runway: how many distinct channels hit #1 in Howto & Style (2024)
SELECT
  COUNTRY,
  COUNT(DISTINCT IFF(UPPER(CAT_TITLE) LIKE 'HOWTO%' OR CATEGORYID = 26, CHANNELTITLE, NULL))
    AS distinct_howto_channels_with_wins
FROM winners
GROUP BY COUNTRY
ORDER BY distinct_howto_channels_with_wins DESC, COUNTRY;

-- B9) Fashion signals in titles (top-10): "haul", "outfit", "lookbook", "sneaker|shoes"
WITH top10 AS (SELECT * FROM daily_rank_non_me WHERE rk <= 10)
SELECT
  COUNTRY,
  SUM(IFF(TITLE ILIKE '%haul%', 1, 0))                           AS haul_mentions,
  SUM(IFF(TITLE ILIKE '%outfit%', 1, 0))                         AS outfit_mentions,
  SUM(IFF(TITLE ILIKE '%lookbook%', 1, 0))                       AS lookbook_mentions,
  SUM(IFF(TITLE ILIKE '%sneaker%' OR TITLE ILIKE '%shoes%',1,0)) AS shoe_mentions
FROM top10
GROUP BY COUNTRY
ORDER BY shoe_mentions DESC, COUNTRY;

-- =========================
-- END (PART 4, year = 2024)
-- If any table returns empty, remove or change the YEAR filter.
-- =========================
