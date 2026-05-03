-- =====================
-- DATA CLEANING 
-- =====================

-- Q1: Find a category name that shows up more than once
--     (we ignore the categoryid; show just one example row)
SELECT CATEGORY_TITLE
FROM table_youtube_category
GROUP BY CATEGORY_TITLE
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC, CATEGORY_TITLE
LIMIT 1;

-- Q2: Find category names that appear in only ONE country
SELECT CATEGORY_TITLE
FROM table_youtube_category
GROUP BY CATEGORY_TITLE
HAVING COUNT(DISTINCT COUNTRY) = 1
ORDER BY CATEGORY_TITLE;

-- Q3: In the FINAL table, which CATEGORYID has a missing title?
--     If nothing is missing, return the word 'None'
SELECT COALESCE(
  (SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY x)
     FROM (
       SELECT DISTINCT TO_VARCHAR(CATEGORYID) AS x
       FROM table_youtube_final
       WHERE CATEGORYID IS NOT NULL
         AND (CATEGORY_TITLE IS NULL OR TRIM(CATEGORY_TITLE) = '')
     )
  ),
  'None'
) AS missing_categoryids;

-- Q4: Fill the missing CATEGORY_TITLE using the CATEGORYID as text
--     (If there are no missing titles, this updates 0 rows — that’s fine)
UPDATE table_youtube_final
SET CATEGORY_TITLE = TO_VARCHAR(CATEGORYID)
WHERE CATEGORYID IS NOT NULL
  AND (CATEGORY_TITLE IS NULL OR TRIM(CATEGORY_TITLE) = '');

-- Q5: List the video titles that don’t have a CHANNELTITLE
SELECT DISTINCT TITLE
FROM table_youtube_final
WHERE CHANNELTITLE IS NULL OR TRIM(CHANNELTITLE) = ''
ORDER BY TITLE;

-- Q6: Delete any bad rows where VIDEO_ID is '#NAME?'
DELETE FROM table_youtube_final
WHERE TRIM(UPPER(REPLACE(VIDEO_ID, '"', ''))) = '#NAME?';

-- Build a table of duplicate rows we want to remove.
-- Duplicates = same (VIDEO_ID, COUNTRY, TRENDING_DATE).
-- We keep the row with the highest VIEW_COUNT (rn = 1) and mark the rest as losers (rn > 1).
CREATE OR REPLACE TABLE table_youtube_duplicates AS
WITH ranked AS (
  SELECT
    IDEAS,
    ROW_NUMBER() OVER (
      PARTITION BY VIDEO_ID, COUNTRY, TRENDING_DATE
      ORDER BY VIEW_COUNT DESC NULLS LAST, IDEAS
    ) AS rn
  FROM table_youtube_final
)
SELECT IDEAS
FROM ranked
WHERE rn > 1;

-- Optional: see how many rows we will remove
SELECT COUNT(*) AS will_remove
FROM table_youtube_duplicates;

-- Delete those duplicate rows from the FINAL table using the IDEAS key
DELETE FROM table_youtube_final f
USING table_youtube_duplicates d
WHERE f.IDEAS = d.IDEAS;

-- Final check: do we have the expected number of rows?
-- If PASS, the count equals 2,597,494. If FAIL, it’s different.
SELECT
  COUNT(*) AS rowcount,
  IFF(COUNT(*) = 2597494, 'PASS', 'FAIL') AS check_2597494,
  2597494 - COUNT(*) AS diff_to_expected
FROM table_youtube_final;
