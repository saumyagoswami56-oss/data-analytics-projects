-- =================
-- DATA ANALYSIS 
-- =================

-- A) For each country, get the TOP 23 most viewed videos in the Gaming category
--    on 2024-04-01. I allow both proper "Gaming" names and the numeric ID 20.
SELECT
  COUNTRY,
  TITLE,
  CHANNELTITLE,
  VIEW_COUNT,
  ROW_NUMBER() OVER (
    PARTITION BY COUNTRY
    ORDER BY VIEW_COUNT DESC NULLS LAST
  ) AS RK
FROM table_youtube_final
WHERE
  -- keep only that day (trim to the first 10 chars = YYYY-MM-DD)
  LEFT(TRIM(TRENDING_DATE), 10) = '2024-04-01'
  -- Gaming filter (case-insensitive name OR category id 20)
  AND (UPPER(CATEGORY_TITLE) LIKE 'GAMING%' OR CATEGORYID = 20)
QUALIFY RK <= 23
ORDER BY COUNTRY, RK;

-- B) For each country, count DISTINCT videos with "BTS" in the title (case-insensitive)
--    and show the biggest counts first.
SELECT
  COUNTRY,
  COUNT(DISTINCT VIDEO_ID) AS CT
FROM table_youtube_final
WHERE TITLE ILIKE '%BTS%'
GROUP BY COUNTRY
ORDER BY CT DESC, COUNTRY;

-- C) Most-viewed video per country per MONTH in 2024,
--    plus likes ratio = (likes/view_count*100) truncated to 2 decimals.
WITH monthly AS (
  SELECT
    COUNTRY,
    DATE_TRUNC('month', TO_DATE(LEFT(TRIM(TRENDING_DATE), 10))) AS YEAR_MONTH,
    TITLE,
    CHANNELTITLE,
    CATEGORY_TITLE,
    VIEW_COUNT,
    LIKES,
    ROW_NUMBER() OVER (
      PARTITION BY COUNTRY, DATE_TRUNC('month', TO_DATE(LEFT(TRIM(TRENDING_DATE), 10)))
      ORDER BY VIEW_COUNT DESC NULLS LAST, TITLE, VIDEO_ID
    ) AS rk
  FROM table_youtube_final
  WHERE YEAR(TO_DATE(LEFT(TRIM(TRENDING_DATE), 10))) = 2024
)
SELECT
  COUNTRY,
  YEAR_MONTH,
  TITLE,
  CHANNELTITLE,
  CATEGORY_TITLE,
  VIEW_COUNT,
  TRUNC( (LIKES / NULLIF(VIEW_COUNT, 0)) * 100, 2 ) AS LIKES_RATIO
FROM monthly
QUALIFY rk = 1
ORDER BY YEAR_MONTH, COUNTRY;

-- D) Before 2022: for each country, find the category with the MOST DISTINCT videos
--    and also show what % that is of the country’s total distinct videos.
WITH filtered AS (
  SELECT COUNTRY, CATEGORY_TITLE, VIDEO_ID
  FROM table_youtube_final
  WHERE YEAR(TO_DATE(LEFT(TRIM(TRENDING_DATE), 10))) < 2022
),
cat_counts AS (
  SELECT COUNTRY, CATEGORY_TITLE, COUNT(DISTINCT VIDEO_ID) AS total_category_video
  FROM filtered
  GROUP BY COUNTRY, CATEGORY_TITLE
),
country_totals AS (
  SELECT COUNTRY, COUNT(DISTINCT VIDEO_ID) AS total_country_video
  FROM filtered
  GROUP BY COUNTRY
),
ranked AS (
  SELECT
    c.COUNTRY,
    c.CATEGORY_TITLE,
    c.total_category_video,
    t.total_country_video,
    ROW_NUMBER() OVER (
      PARTITION BY c.COUNTRY
      ORDER BY c.total_category_video DESC, c.CATEGORY_TITLE
    ) AS rk
  FROM cat_counts c
  JOIN country_totals t USING (COUNTRY)
)
SELECT
  COUNTRY,
  CATEGORY_TITLE,
  total_category_video AS TOTAL_CATEGORY_VIDEO,
  total_country_video  AS TOTAL_COUNTRY_VIDEO,
  TRUNC( (total_category_video / NULLIF(total_country_video, 0)) * 100, 2 ) AS PERCENTAGE
FROM ranked
QUALIFY rk = 1
ORDER BY CATEGORY_TITLE, COUNTRY;

-- E) Which channel has produced the MOST DISTINCT videos overall?
SELECT
  CHANNELTITLE,
  COUNT(DISTINCT VIDEO_ID) AS NUM_DISTINCT_VIDEOS
FROM table_youtube_final
WHERE CHANNELTITLE IS NOT NULL AND TRIM(CHANNELTITLE) <> ''
GROUP BY CHANNELTITLE
ORDER BY NUM_DISTINCT_VIDEOS DESC, CHANNELTITLE
LIMIT 1;
