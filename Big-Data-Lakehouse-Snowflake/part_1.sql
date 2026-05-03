-- create the database if it doesn't exist yet
CREATE DATABASE IF NOT EXISTS assignment_1;

-- switch into my database
USE DATABASE assignment_1;

-- use the public schema
USE SCHEMA PUBLIC;

-- create a stage that points to my Azure blob (where the files live)
CREATE OR REPLACE STAGE stage_assignment
URL='azure://utsbdewilliam.blob.core.windows.net/bde-assignment/'
CREDENTIALS=(AZURE_SAS_TOKEN='?sv=2024-11-04&ss=b&srt=co&sp=rwdlaciytfx&se=2025-12-29T15:18:18Z&st=2025-08-21T08:03:18Z&spr=https&sig=z%2Bi2QcGO4jY%2FCeVrYI%2Ft6AU2dgzoAUGW9fO9oGThxNw%3D');

-- quick check: I can see the trending CSV files in the stage
LIST @stage_assignment PATTERN='.*_youtube_trending_data\.csv';

-- quick check: I can see the category JSON files in the stage
LIST @stage_assignment PATTERN='.*_category_id\.json';

-- list everything in the stage (sanity)
LIST @stage_assignment/;

-- create the external table on the trending CSVs (Snowflake reads them in place)
CREATE OR REPLACE EXTERNAL TABLE ex_table_youtube_trending
WITH LOCATION = @stage_assignment
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
PATTERN = '.*_youtube_trending_data\.csv$';

-- create the external table on the category JSON files
-- NOTE: I originally typed @stage_assignment_1 here; I only have stage_assignment above.
-- If @stage_assignment_1 doesn't exist, I should change this to @stage_assignment.
CREATE OR REPLACE EXTERNAL TABLE ex_table_youtube_category
WITH LOCATION = @stage_assignment
FILE_FORMAT = (TYPE = JSON)
PATTERN = '.*_category_id\.json$';

-- land the trending external data into a proper Snowflake table with correct types
-- also derive COUNTRY from the file name (CSV doesn't include country column)
CREATE OR REPLACE TABLE table_youtube_trending AS
SELECT
  VALUE:c1::STRING                                   AS VIDEO_ID,
  VALUE:c2::STRING                                   AS TITLE,
  TO_DATE(LEFT(VALUE:c3::STRING,10))                 AS PUBLISHEDAT,     -- date only
  VALUE:c4::STRING                                   AS CHANNELID,
  VALUE:c5::STRING                                   AS CHANNELTITLE,
  VALUE:c6::NUMBER                                   AS CATEGORYID,
  TO_DATE(LEFT(VALUE:c7::STRING,10))                 AS TRENDING_DATE,   -- date only
  TRY_TO_NUMBER(VALUE:c8::STRING)                    AS VIEW_COUNT,
  TRY_TO_NUMBER(VALUE:c9::STRING)                    AS LIKES,
  TRY_TO_NUMBER(VALUE:c10::STRING)                   AS DISLIKES,
  TRY_TO_NUMBER(VALUE:c11::STRING)                   AS COMMENT_COUNT,
  SPLIT_PART(SPLIT_PART(METADATA$FILENAME,'/',-1),'_',1) AS COUNTRY
FROM ex_table_youtube_trending;


SELECT
  VIDEO_ID,
  TITLE,
  TO_CHAR(PUBLISHEDAT,  'YYYY-MM-DD') AS PUBLISHEDAT,
  CHANNELID,
  CHANNELTITLE,
  CATEGORYID,
  TO_CHAR(TRENDING_DATE,'YYYY-MM-DD') AS TRENDING_DATE,
  VIEW_COUNT,
  LIKES,
  DISLIKES,
  COMMENT_COUNT,
  COUNTRY
FROM table_youtube_trending
WHERE COUNTRY = 'DE'
  AND TRENDING_DATE = TO_DATE('2020-08-12')
ORDER BY VIEW_COUNT DESC, VIDEO_ID
LIMIT 10;

-- build the category lookup table by flattening the JSON
-- (also derive COUNTRY from the filename just like above)
CREATE OR REPLACE TABLE table_youtube_category AS
WITH src AS (
  SELECT
    value,
    SPLIT_PART(SPLIT_PART(METADATA$FILENAME,'/',-1),'_',1) AS COUNTRY
  FROM ex_table_youtube_category
),
items AS (
  SELECT s.COUNTRY, f.value AS item
  FROM src s,
       LATERAL FLATTEN(input => COALESCE(s.value:items, s.value)) f
)
SELECT
  COUNTRY,
  item:id::NUMBER            AS CATEGORYID,
  item:snippet:title::STRING AS CATEGORY_TITLE
FROM items
WHERE item:id IS NOT NULL;

-- preview the category table for DE so it looks like the screenshot
SELECT
  COUNTRY,
  CATEGORYID,
  CATEGORY_TITLE
FROM table_youtube_category
WHERE COUNTRY = 'DE'
ORDER BY CATEGORYID
LIMIT 20;

-- create the FINAL table by left-joining trending to category (so I don't lose any trending rows)
-- also generate a unique ID column "IDEAS" with UUID_STRING()
CREATE OR REPLACE TABLE table_youtube_final AS
WITH cat_dedup AS (
  SELECT
    COUNTRY,
    CATEGORYID::NUMBER        AS CATEGORYID,
    MIN(CATEGORY_TITLE)       AS CATEGORY_TITLE
  FROM table_youtube_category
  GROUP BY COUNTRY, CATEGORYID::NUMBER
)
SELECT
  UUID_STRING()                             AS IDEAS,          -- new UUID column
  t.VIDEO_ID,
  t.TITLE,
  CAST(t.PUBLISHEDAT   AS DATE)             AS PUBLISHEDAT,
  t.CHANNELID,
  t.CHANNELTITLE,
  CAST(t.CATEGORYID    AS NUMBER)           AS CATEGORYID,
  c.CATEGORY_TITLE,
  CAST(t.TRENDING_DATE AS DATE)             AS TRENDING_DATE,
  TRY_TO_NUMBER(t.VIEW_COUNT)               AS VIEW_COUNT,
  TRY_TO_NUMBER(t.LIKES)                    AS LIKES,
  TRY_TO_NUMBER(t.DISLIKES)                 AS DISLIKES,
  TRY_TO_NUMBER(t.COMMENT_COUNT)            AS COMMENT_COUNT,
  t.COUNTRY
FROM table_youtube_trending t
LEFT JOIN cat_dedup c
  ON t.COUNTRY = c.COUNTRY
 AND CAST(t.CATEGORYID AS NUMBER) = c.CATEGORYID;

 -- FINAL TABLE
SELECT
  IDEAS         AS ID,
  VIDEO_ID,
  TITLE,
  TO_CHAR(PUBLISHEDAT,  'YYYY-MM-DD') AS PUBLISHEDAT,
  CHANNELID,
  CHANNELTITLE,
  CATEGORYID,
  CATEGORY_TITLE,
  TO_CHAR(TRENDING_DATE,'YYYY-MM-DD') AS TRENDING_DATE,
  VIEW_COUNT,
  LIKES,
  DISLIKES,
  COMMENT_COUNT,
  COUNTRY
FROM table_youtube_final
WHERE COUNTRY = 'IN' AND TRENDING_DATE = DATE '2020-08-12'
ORDER BY VIEW_COUNT DESC, VIDEO_ID
LIMIT 50;


-- ------------------------------------------------------------
-- NOTE: the block below rebuilds table_youtube_trending AGAIN,
-- this time keeping everything as STRING (raw). Running this
-- will overwrite the nicely-typed table I created earlier.
-- I should only run this if I really want the raw string version.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE table_youtube_trending AS
SELECT
  VALUE:c1::STRING  AS VIDEO_ID,
  VALUE:c2::STRING  AS TITLE,
  VALUE:c3::STRING  AS PUBLISHEDAT,
  VALUE:c4::STRING  AS CHANNELID,
  VALUE:c5::STRING  AS CHANNELTITLE,
  VALUE:c6::STRING  AS CATEGORYID,
  VALUE:c7::STRING  AS TRENDING_DATE,       
  VALUE:c8::STRING  AS VIEW_COUNT,
  VALUE:c9::STRING  AS LIKES,
  VALUE:c10::STRING AS DISLIKES,
  VALUE:c11::STRING AS COMMENT_COUNT,
 
  SPLIT_PART(SPLIT_PART(METADATA$FILENAME,'/',-1),'_',1) AS COUNTRY
FROM ex_table_youtube_trending;

-- simple row count on the final table 
SELECT COUNT(*) FROM table_youtube_final;
