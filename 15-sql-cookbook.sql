/* =============================================================================
   15 — SNOWFLAKE SQL COOKBOOK (SnowPro Core COF-C02 hands-on companion)
   =============================================================================
   HOW TO RUN
   - Open a Snowsight SQL worksheet in a trial account and run the sections in
     order. Run statement by statement (Ctrl/Cmd+Enter), or select a whole
     section and run it.
   - The script is self-contained. It generates its own data and moves files
     through an internal stage by unloading and reloading, so you don't need
     PUT, a local client, or a cloud bucket.
   - Uses the roles every trial user has: ACCOUNTADMIN, SECURITYADMIN,
     USERADMIN, SYSADMIN.
   - Cost: an X-SMALL warehouse with 60-second auto-suspend. A full run uses
     well under 1 credit.

   EDITION LABELS
   - Unmarked sections run on Standard edition and above.
   - Blocks marked  >>> [ENTERPRISE+] <<<  are commented out. Uncomment them
     only if your account is Enterprise or higher. Trial signups let you pick
     the edition; Enterprise is the usual default.
   - Blocks marked  >>> [BUSINESS CRITICAL+] <<<  or  >>> [EXTERNAL RESOURCES] <<<
     are reference-only and need extra setup.
   - A few statements are commented because they intentionally fail
     (marked EXPECTED ERROR) or need a client tool (PUT/GET).

   CONTENTS
     00  Setup: warehouse, database, schema
     01  Context functions and account info
     02  Warehouses: resize, properties, multi-cluster [ENT]
     03  Table types, sequences, identity
     04  Sample data generation
     05  File formats and stages (incl. directory table)
     06  Unloading: CSV, Parquet, partitioned
     07  Querying staged files directly
     08  Bulk loading with COPY INTO and load metadata
     09  Validation and error handling
     10  Schema inference (INFER_SCHEMA / USING TEMPLATE)
     11  Snowpipe (REST-style pipe on an internal stage)
     12  Semi-structured data: JSON round trip, FLATTEN
     13  Transformations: QUALIFY, MERGE, PIVOT, INSERT ALL, sampling
     14  Views: standard, secure, materialized [ENT]
     15  Time Travel, UNDROP, retention
     16  Zero-copy cloning
     17  RBAC: roles, grants, future grants, managed access
     18  Network policy (created, not applied)
     19  Column/row security, tags, classification [ENT]
     20  Streams and tasks
     21  Dynamic tables
     22  UDFs, UDTFs, stored procedures, Snowpark
     23  Performance: caches, clustering, query history
     24  Search optimization, QAS [ENT]
     25  Resource monitors
     26  Secure data sharing
     27  Unstructured data URLs
     28  Governance: ACCOUNT_USAGE vs INFORMATION_SCHEMA, parameters
     29  Replication and failover [BC+]  (reference only)
     99  Cleanup (commented)
   ============================================================================= */


/* =============================================================================
   00  SETUP
   ============================================================================= */
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS PREP_WH
  WAREHOUSE_SIZE      = 'XSMALL'
  AUTO_SUSPEND        = 60          -- seconds (default would be 600)
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT             = 'SnowPro Core prep cookbook';

USE WAREHOUSE PREP_WH;

CREATE DATABASE IF NOT EXISTS PREP_DB COMMENT = 'SnowPro Core prep cookbook';
CREATE SCHEMA   IF NOT EXISTS PREP_DB.CORE;
USE SCHEMA PREP_DB.CORE;


/* =============================================================================
   01  CONTEXT FUNCTIONS AND ACCOUNT INFO
   ============================================================================= */
SELECT CURRENT_ORGANIZATION_NAME() AS org,
       CURRENT_ACCOUNT_NAME()      AS account_name,
       CURRENT_ACCOUNT()           AS account_locator,
       CURRENT_REGION()            AS region,
       CURRENT_VERSION()           AS snowflake_version,
       CURRENT_USER()              AS usr,
       CURRENT_ROLE()              AS role,
       CURRENT_WAREHOUSE()         AS wh,
       CURRENT_DATABASE()          AS db,
       CURRENT_SCHEMA()            AS sch;

-- Metadata-only operations: answered by cloud services
SHOW DATABASES LIKE 'PREP_DB';
SHOW WAREHOUSES LIKE 'PREP_WH';


/* =============================================================================
   02  WAREHOUSES
   ============================================================================= */
-- Scale UP (resize). Running queries finish on the old size; new ones use the new size.
ALTER WAREHOUSE PREP_WH SET WAREHOUSE_SIZE = 'SMALL';
ALTER WAREHOUSE PREP_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- Timeouts at warehouse level (the lower of session and warehouse wins)
ALTER WAREHOUSE PREP_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 3600
                            STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 600;
SHOW PARAMETERS LIKE 'STATEMENT_%' IN WAREHOUSE PREP_WH;

/* >>> [ENTERPRISE+] <<<  Multi-cluster warehouse: scale OUT for concurrency
ALTER WAREHOUSE PREP_WH SET
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  SCALING_POLICY    = 'ECONOMY';      -- or 'STANDARD' (default)
SHOW WAREHOUSES LIKE 'PREP_WH';       -- min_cluster_count, max_cluster_count, scaling_policy
ALTER WAREHOUSE PREP_WH SET MIN_CLUSTER_COUNT = 1 MAX_CLUSTER_COUNT = 1;
*/

/* Optional: Snowpark-optimized warehouse (higher credit rate; created suspended)
CREATE WAREHOUSE IF NOT EXISTS PREP_SNOWPARK_WH
  WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED' WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60 INITIALLY_SUSPENDED = TRUE;
DROP WAREHOUSE IF EXISTS PREP_SNOWPARK_WH;
*/


/* =============================================================================
   03  TABLE TYPES, SEQUENCES, IDENTITY
   ============================================================================= */
CREATE OR REPLACE TRANSIENT TABLE stg_transient (id INT, payload STRING)
  DATA_RETENTION_TIME_IN_DAYS = 0;                 -- transient: 0 or 1 day, no Fail-safe

CREATE OR REPLACE TEMPORARY TABLE tmp_session (id INT);   -- gone when the session ends

SHOW TABLES LIKE 'STG_TRANSIENT';                  -- "kind" = TRANSIENT
SHOW TABLES LIKE 'TMP_SESSION';                    -- "kind" = TEMPORARY

-- Sequences (not gap-free) and identity columns
CREATE OR REPLACE SEQUENCE seq_ticket START = 1000 INCREMENT = 10;
CREATE OR REPLACE TABLE tickets (
  ticket_no NUMBER DEFAULT seq_ticket.NEXTVAL,
  row_id    NUMBER AUTOINCREMENT START 1 INCREMENT 1,
  note      STRING NOT NULL,                       -- NOT NULL is enforced
  CONSTRAINT pk_tickets PRIMARY KEY (ticket_no)    -- informational only
);
INSERT INTO tickets (note) VALUES ('first'), ('second'), ('third');
SELECT * FROM tickets;

-- The PRIMARY KEY is NOT enforced on standard tables: this duplicate succeeds
INSERT INTO tickets (ticket_no, note) VALUES (1000, 'duplicate PK accepted');
SELECT ticket_no, COUNT(*) FROM tickets GROUP BY ticket_no HAVING COUNT(*) > 1;

-- EXPECTED ERROR: NOT NULL is enforced
-- INSERT INTO tickets (note) VALUES (NULL);


/* =============================================================================
   04  SAMPLE DATA GENERATION
   ============================================================================= */
CREATE OR REPLACE TABLE customers AS
SELECT ROW_NUMBER() OVER (ORDER BY SEQ4())                                         AS customer_id,
       'Customer_' || ROW_NUMBER() OVER (ORDER BY SEQ4())                          AS name,
       'customer' || ROW_NUMBER() OVER (ORDER BY SEQ4()) || '@example.com'         AS email,
       GET(ARRAY_CONSTRUCT('NA','EMEA','APAC','LATAM'), UNIFORM(0, 3, RANDOM()))::STRING AS region,
       DATEADD(day, -1 * UNIFORM(0, 1000, RANDOM()), CURRENT_DATE())               AS signup_date
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

CREATE OR REPLACE TABLE orders AS
SELECT ROW_NUMBER() OVER (ORDER BY SEQ4())                                         AS order_id,
       UNIFORM(1, 1000, RANDOM())                                                  AS customer_id,
       DATEADD(day, -1 * UNIFORM(0, 365, RANDOM()), CURRENT_DATE())                AS order_date,
       (UNIFORM(500, 50000, RANDOM()) / 100)::NUMBER(10,2)                         AS amount,
       GET(ARRAY_CONSTRUCT('NEW','SHIPPED','DELIVERED','RETURNED'), UNIFORM(0, 3, RANDOM()))::STRING AS status
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

SELECT COUNT(*) FROM customers;
SELECT COUNT(*), MIN(order_date), MAX(order_date), SUM(amount) FROM orders;
DESC TABLE orders;


/* =============================================================================
   05  FILE FORMATS AND STAGES
   ============================================================================= */
CREATE OR REPLACE FILE FORMAT ff_csv
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1                         -- load-time option
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  COMPRESSION = GZIP;

CREATE OR REPLACE FILE FORMAT ff_json    TYPE = JSON STRIP_OUTER_ARRAY = TRUE;
CREATE OR REPLACE FILE FORMAT ff_parquet TYPE = PARQUET;
SHOW FILE FORMATS;

-- Named internal stage with server-side encryption (needed for usable pre-signed URLs)
-- and a directory table
CREATE OR REPLACE STAGE stg_internal
  FILE_FORMAT = ff_csv
  DIRECTORY   = (ENABLE = TRUE)
  ENCRYPTION  = (TYPE = 'SNOWFLAKE_SSE');

-- The three kinds of internal stage
LIST @~;                -- user stage
LIST @%orders;          -- table stage of ORDERS
LIST @stg_internal;     -- named stage (empty for now)

/* CLIENT ONLY (SnowSQL / Snowflake CLI). PUT and GET can't run in a Snowsight worksheet.
PUT file:///tmp/orders.csv @stg_internal/manual/ AUTO_COMPRESS = TRUE PARALLEL = 4;
GET @stg_internal/unload/ file:///tmp/unload/;
*/

/* >>> [EXTERNAL RESOURCES] <<<  External stage via a storage integration
   (needs your own S3 bucket and IAM role; ACCOUNTADMIN creates the integration)
USE ROLE ACCOUNTADMIN;
CREATE STORAGE INTEGRATION s3_prep_int
  TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3' ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<acct>:role/<role>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/prep/');
DESC INTEGRATION s3_prep_int;        -- copy STORAGE_AWS_IAM_USER_ARN / EXTERNAL_ID into the IAM trust policy
GRANT USAGE ON INTEGRATION s3_prep_int TO ROLE SYSADMIN;
USE ROLE SYSADMIN;
CREATE STAGE PREP_DB.CORE.stg_s3 URL = 's3://<bucket>/prep/' STORAGE_INTEGRATION = s3_prep_int;
*/


/* =============================================================================
   06  UNLOADING (COPY INTO <location>)
   ============================================================================= */
-- CSV: multiple files written in parallel by default (MAX_FILE_SIZE default = 16 MB)
COPY INTO @stg_internal/orders/
  FROM orders
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  HEADER = TRUE
  OVERWRITE = TRUE
  MAX_FILE_SIZE = 1000000;            -- ~1 MB so you see several files

LIST @stg_internal/orders/;

-- Parquet with column names preserved (HEADER = TRUE)
COPY INTO @stg_internal/parquet/
  FROM orders
  FILE_FORMAT = (TYPE = PARQUET)
  HEADER = TRUE
  OVERWRITE = TRUE;

-- Partitioned unload (Hive-style folders)
COPY INTO @stg_internal/by_status/
  FROM orders
  PARTITION BY ('status=' || status)
  FILE_FORMAT = (TYPE = PARQUET)
  HEADER = TRUE;

-- Single file (needs an explicit file name to control the extension)
COPY INTO @stg_internal/single/customers.csv.gz
  FROM customers
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  HEADER = TRUE SINGLE = TRUE OVERWRITE = TRUE;

LIST @stg_internal;


/* =============================================================================
   07  QUERYING STAGED FILES DIRECTLY
   ============================================================================= */
SELECT METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, $1, $2, $3, $4, $5
FROM @stg_internal/orders/ (FILE_FORMAT => 'ff_csv')
LIMIT 10;

SELECT $1:ORDER_ID::NUMBER AS order_id, $1:STATUS::STRING AS status
FROM @stg_internal/parquet/ (FILE_FORMAT => 'ff_parquet')
LIMIT 5;

-- Directory table (internal stages need a manual refresh)
ALTER STAGE stg_internal REFRESH;
SELECT relative_path, size, last_modified FROM DIRECTORY(@stg_internal) ORDER BY relative_path;


/* =============================================================================
   08  BULK LOADING WITH COPY INTO AND LOAD METADATA
   ============================================================================= */
CREATE OR REPLACE TABLE orders_loaded LIKE orders;

COPY INTO orders_loaded
  FROM @stg_internal/orders/
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  ON_ERROR = ABORT_STATEMENT;          -- the default for bulk COPY

SELECT COUNT(*) FROM orders_loaded;    -- 100,000

-- Run again: files are SKIPPED thanks to the 64-day load metadata
COPY INTO orders_loaded FROM @stg_internal/orders/ FILE_FORMAT = (FORMAT_NAME = ff_csv);
SELECT COUNT(*) FROM orders_loaded;    -- still 100,000

-- FORCE = TRUE would reload and DUPLICATE the rows:
-- COPY INTO orders_loaded FROM @stg_internal/orders/ FILE_FORMAT = (FORMAT_NAME = ff_csv) FORCE = TRUE;

-- Transforming COPY: reorder, cast, add metadata columns
CREATE OR REPLACE TABLE orders_with_lineage (
  order_id NUMBER, status STRING, amount NUMBER(10,2),
  src_file STRING, src_row NUMBER, loaded_at TIMESTAMP_LTZ);

COPY INTO orders_with_lineage
  FROM (SELECT $1::NUMBER, $5, $4::NUMBER(10,2),
               METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
        FROM @stg_internal/orders/)
  FILE_FORMAT = (FORMAT_NAME = ff_csv);

SELECT * FROM orders_with_lineage LIMIT 5;

-- Load history
SELECT file_name, status, row_count, row_parsed, first_error_message, last_load_time
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
       TABLE_NAME => 'ORDERS_LOADED',
       START_TIME => DATEADD(hour, -1, CURRENT_TIMESTAMP())));


/* =============================================================================
   09  VALIDATION AND ERROR HANDLING
   ============================================================================= */
-- Create a file with 5 good rows and 1 bad row
COPY INTO @stg_internal/bad/bad_orders.csv.gz
  FROM (
    SELECT order_id::STRING, customer_id::STRING, order_date::STRING, amount::STRING, status
    FROM orders WHERE order_id <= 5
    UNION ALL
    SELECT 'oops', '1', 'not-a-date', 'abc', 'NEW'
  )
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  HEADER = TRUE SINGLE = TRUE OVERWRITE = TRUE;

-- Dry run: returns errors and loads NOTHING
COPY INTO orders_loaded FROM @stg_internal/bad/
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  VALIDATION_MODE = RETURN_ERRORS;

-- Dry run: preview the first rows
COPY INTO orders_loaded FROM @stg_internal/bad/
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  VALIDATION_MODE = RETURN_2_ROWS;

-- EXPECTED ERROR with the default ON_ERROR = ABORT_STATEMENT:
-- COPY INTO orders_loaded FROM @stg_internal/bad/ FILE_FORMAT = (FORMAT_NAME = ff_csv);

-- Load good rows, skip bad ones
COPY INTO orders_loaded FROM @stg_internal/bad/
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  ON_ERROR = CONTINUE;                       -- alternatives: SKIP_FILE, SKIP_FILE_3, 'SKIP_FILE_10%'

-- Inspect the rejected rows of the last COPY in this session
SELECT * FROM TABLE(VALIDATE(orders_loaded, JOB_ID => '_last'));


/* =============================================================================
   10  SCHEMA INFERENCE
   ============================================================================= */
SELECT * FROM TABLE(INFER_SCHEMA(LOCATION => '@stg_internal/parquet/', FILE_FORMAT => 'ff_parquet'));

CREATE OR REPLACE TABLE orders_from_parquet
  USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(INFER_SCHEMA(LOCATION => '@stg_internal/parquet/', FILE_FORMAT => 'ff_parquet')));

COPY INTO orders_from_parquet
  FROM @stg_internal/parquet/
  FILE_FORMAT = (FORMAT_NAME = ff_parquet)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

SELECT COUNT(*) FROM orders_from_parquet;
DESC TABLE orders_from_parquet;


/* =============================================================================
   11  SNOWPIPE
   Internal stages can't use AUTO_INGEST (that needs cloud event notifications on
   an external stage). Here the pipe is fed with ALTER PIPE ... REFRESH, which
   queues files staged in the last 7 days. Snowpipe compute is serverless.
   ============================================================================= */
CREATE OR REPLACE TABLE orders_pipe LIKE orders;

CREATE OR REPLACE PIPE p_orders
  COMMENT = 'Snowpipe demo on an internal stage'
AS
  COPY INTO orders_pipe
  FROM @stg_internal/orders/
  FILE_FORMAT = (FORMAT_NAME = ff_csv);   -- Snowpipe default ON_ERROR = SKIP_FILE

-- If your release rejects REFRESH for internal-stage pipes, the equivalent is the
-- Snowpipe REST insertFiles endpoint (key-pair auth), which needs a client.
ALTER PIPE p_orders REFRESH;
SELECT SYSTEM$PIPE_STATUS('p_orders');
SHOW PIPES LIKE 'P_ORDERS';

-- Wait about a minute, then:
SELECT COUNT(*) FROM orders_pipe;
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'ORDERS_PIPE', START_TIME => DATEADD(hour, -1, CURRENT_TIMESTAMP())));

ALTER PIPE p_orders SET PIPE_EXECUTION_PAUSED = TRUE;

/* >>> [EXTERNAL RESOURCES] <<<  Auto-ingest pipe on an external S3 stage
CREATE PIPE p_orders_auto AUTO_INGEST = TRUE AS
  COPY INTO orders_pipe FROM @stg_s3/orders/ FILE_FORMAT = (FORMAT_NAME = ff_csv);
SHOW PIPES;    -- notification_channel = SQS ARN to configure on the S3 bucket event
*/


/* =============================================================================
   12  SEMI-STRUCTURED DATA
   ============================================================================= */
-- Build nested JSON documents (one per customer) and unload them as NDJSON
COPY INTO @stg_internal/json/
  FROM (
    SELECT OBJECT_CONSTRUCT(
             'customer_id', c.customer_id,
             'name',        c.name,
             'contact',     OBJECT_CONSTRUCT('email', c.email, 'region', c.region),
             'orders',      ARRAY_AGG(OBJECT_CONSTRUCT('order_id', o.order_id,
                                                       'amount',   o.amount,
                                                       'status',   o.status)))
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE c.customer_id <= 50
    GROUP BY c.customer_id, c.name, c.email, c.region
  )
  FILE_FORMAT = (TYPE = JSON)          -- JSON unload needs exactly one VARIANT/OBJECT column
  OVERWRITE = TRUE;

CREATE OR REPLACE TABLE raw_customers (
  v         VARIANT,
  src_file  STRING,
  loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

COPY INTO raw_customers (v, src_file)
  FROM (SELECT $1, METADATA$FILENAME FROM @stg_internal/json/)
  FILE_FORMAT = (FORMAT_NAME = ff_json);

-- Path notation, casting, case sensitivity
SELECT v:customer_id::NUMBER       AS customer_id,
       v:name                      AS name_variant,     -- has double quotes
       v:name::STRING              AS name_string,      -- quotes removed
       v:contact.email::STRING     AS email,            -- dot notation
       v['contact']['region']::STRING AS region,        -- bracket notation
       v:Name                      AS wrong_case,       -- NULL: keys are case-sensitive
       v:orders[0].amount::NUMBER(10,2) AS first_order_amount,
       ARRAY_SIZE(v:orders)        AS n_orders,
       TYPEOF(v:orders)            AS t
FROM raw_customers
LIMIT 5;

-- FLATTEN: one row per array element
SELECT r.v:customer_id::NUMBER       AS customer_id,
       f.index                       AS idx,
       f.value:order_id::NUMBER      AS order_id,
       f.value:amount::NUMBER(10,2)  AS amount,
       f.value:status::STRING        AS status
FROM raw_customers r,
     LATERAL FLATTEN(INPUT => r.v:orders) f
ORDER BY customer_id, idx
LIMIT 20;

-- FLATTEN over an OBJECT: KEY / VALUE / PATH
SELECT f.key, f.value, f.path, f.index
FROM raw_customers r, LATERAL FLATTEN(INPUT => r.v:contact) f
WHERE r.v:customer_id = 1;

-- OUTER => TRUE keeps rows whose array is empty or missing
SELECT t.id, f.value
FROM (SELECT 1 AS id, PARSE_JSON('{"items":[10,20]}') AS j
      UNION ALL
      SELECT 2, PARSE_JSON('{"items":[]}')) t,
     LATERAL FLATTEN(INPUT => t.j:items, OUTER => TRUE) f;

-- RECURSIVE => TRUE walks every nested level
SELECT f.path, f.key, f.value
FROM (SELECT PARSE_JSON('{"a":{"b":{"c":1}},"d":[1,{"e":2}]}') AS j) t,
     LATERAL FLATTEN(INPUT => t.j, RECURSIVE => TRUE) f;

-- JSON null vs SQL NULL
SELECT PARSE_JSON('{"x":null}'):x            AS json_null,
       PARSE_JSON('{"x":null}'):x IS NULL    AS is_sql_null,     -- FALSE
       IS_NULL_VALUE(PARSE_JSON('{"x":null}'):x) AS is_json_null, -- TRUE
       PARSE_JSON('{"x":null}'):missing IS NULL AS missing_is_null; -- TRUE

-- Constructors
SELECT OBJECT_CONSTRUCT('a', 1, 'b', NULL)           AS drops_nulls,
       OBJECT_CONSTRUCT_KEEP_NULL('a', 1, 'b', NULL) AS keeps_nulls,
       ARRAY_CONSTRUCT(1, 2, 3)                      AS arr,
       TRY_PARSE_JSON('{bad json')                   AS try_parse;


/* =============================================================================
   13  TRANSFORMATIONS
   ============================================================================= */
-- QUALIFY: latest order per customer
SELECT customer_id, order_id, order_date, amount
FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) = 1
ORDER BY customer_id
LIMIT 10;

-- MERGE (upsert) from the JSON landing table into a dimension
CREATE OR REPLACE TABLE dim_customer (
  customer_id NUMBER, email STRING, region STRING, updated_at TIMESTAMP_LTZ);

MERGE INTO dim_customer d
USING (
  SELECT v:customer_id::NUMBER AS customer_id,
         v:contact.email::STRING AS email,
         v:contact.region::STRING AS region
  FROM raw_customers
  QUALIFY ROW_NUMBER() OVER (PARTITION BY v:customer_id ORDER BY loaded_at DESC) = 1   -- dedupe source
) s
ON d.customer_id = s.customer_id
WHEN MATCHED AND (d.email <> s.email OR d.region <> s.region) THEN
  UPDATE SET d.email = s.email, d.region = s.region, d.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (customer_id, email, region, updated_at)
  VALUES (s.customer_id, s.email, s.region, CURRENT_TIMESTAMP());

SELECT COUNT(*) FROM dim_customer;

-- PIVOT
SELECT *
FROM (SELECT c.region, o.status, o.amount
      FROM orders o JOIN customers c ON c.customer_id = o.customer_id)
PIVOT (SUM(amount) FOR status IN ('NEW', 'SHIPPED', 'DELIVERED', 'RETURNED')) AS p
ORDER BY region;

-- ROLLUP
SELECT c.region, o.status, SUM(o.amount) AS revenue
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY ROLLUP (c.region, o.status)
ORDER BY c.region NULLS LAST, o.status NULLS LAST;

-- Multi-table insert: INSERT FIRST routes each row to the first matching branch
CREATE OR REPLACE TABLE big_orders   LIKE orders;
CREATE OR REPLACE TABLE small_orders LIKE orders;
INSERT FIRST
  WHEN amount >= 250 THEN INTO big_orders
  ELSE INTO small_orders
SELECT * FROM orders;
SELECT (SELECT COUNT(*) FROM big_orders) AS big, (SELECT COUNT(*) FROM small_orders) AS small;

-- Recursive CTE
WITH RECURSIVE nums (n) AS (
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM nums WHERE n < 10)
SELECT n FROM nums;

-- Sampling
SELECT COUNT(*) FROM orders SAMPLE BERNOULLI (1);          -- ~1% of rows
SELECT COUNT(*) FROM orders SAMPLE SYSTEM (10) SEED (42);  -- block sampling, repeatable
SELECT * FROM orders SAMPLE (5 ROWS);                      -- fixed number of rows

-- Approximate vs exact
SELECT COUNT(DISTINCT customer_id)        AS exact_distinct,
       APPROX_COUNT_DISTINCT(customer_id) AS hll_distinct,
       APPROX_PERCENTILE(amount, 0.5)     AS approx_median
FROM orders;
SELECT APPROX_TOP_K(status, 3) FROM orders;

-- Safe casting
SELECT TRY_CAST('12x' AS NUMBER) AS bad_num, TRY_TO_DATE('2024-02-30') AS bad_date, IFF(1 > 0, 'y', 'n') AS iff_demo;


/* =============================================================================
   14  VIEWS
   ============================================================================= */
CREATE OR REPLACE VIEW v_region_sales AS
SELECT c.region, COUNT(*) AS orders, SUM(o.amount) AS revenue
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.region;

CREATE OR REPLACE SECURE VIEW v_region_sales_secure AS
SELECT c.region, COUNT(*) AS orders, SUM(o.amount) AS revenue
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.region;

SHOW VIEWS LIKE 'V_REGION%';                          -- is_secure column
SELECT GET_DDL('VIEW', 'v_region_sales_secure');      -- visible to the owner only

/* >>> [ENTERPRISE+] <<<  Materialized view (single table, no joins)
CREATE OR REPLACE MATERIALIZED VIEW mv_daily_sales AS
SELECT order_date, COUNT(*) AS orders, SUM(amount) AS revenue
FROM orders
GROUP BY order_date;
SELECT * FROM mv_daily_sales ORDER BY order_date DESC LIMIT 10;
SHOW MATERIALIZED VIEWS;                              -- behind_by, refreshed_on
-- EXPECTED ERROR: materialized views can't contain joins
-- CREATE MATERIALIZED VIEW mv_bad AS SELECT * FROM orders o JOIN customers c ON c.customer_id = o.customer_id;
*/


/* =============================================================================
   15  TIME TRAVEL, UNDROP, RETENTION
   ============================================================================= */
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN TABLE orders;   -- default 1

-- Make a change and capture its query ID
UPDATE orders SET status = 'CANCELLED' WHERE order_id <= 10;
SET upd_qid = LAST_QUERY_ID();

SELECT COUNT(*) AS cancelled_now FROM orders WHERE status = 'CANCELLED';
SELECT COUNT(*) AS cancelled_before
FROM orders BEFORE(STATEMENT => $upd_qid)
WHERE status = 'CANCELLED';                                           -- 0

-- Restore by cloning the table as it was before the update
CREATE OR REPLACE TABLE orders_before_update CLONE orders BEFORE(STATEMENT => $upd_qid);
SELECT status, COUNT(*) FROM orders_before_update WHERE order_id <= 10 GROUP BY status;

-- Other AT forms (OFFSET is in SECONDS; must be within retention and after table creation)
-- SELECT COUNT(*) FROM orders AT(OFFSET => -60);
-- SELECT COUNT(*) FROM orders AT(TIMESTAMP => DATEADD(minute, -5, CURRENT_TIMESTAMP()));

-- DROP / UNDROP
DROP TABLE orders_loaded;
SHOW TABLES HISTORY LIKE 'ORDERS_LOADED';                             -- dropped_on is set
UNDROP TABLE orders_loaded;
SELECT COUNT(*) FROM orders_loaded;

-- Retention: Standard allows 0 or 1 day on permanent tables
ALTER TABLE orders SET DATA_RETENTION_TIME_IN_DAYS = 1;

/* >>> [ENTERPRISE+] <<<  Extended Time Travel (up to 90 days on permanent objects)
ALTER TABLE orders SET DATA_RETENTION_TIME_IN_DAYS = 30;
ALTER SCHEMA PREP_DB.CORE SET DATA_RETENTION_TIME_IN_DAYS = 7;
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN TABLE orders;
ALTER TABLE orders SET DATA_RETENTION_TIME_IN_DAYS = 1;
*/

-- EXPECTED ERROR: transient tables allow at most 1 day
-- ALTER TABLE stg_transient SET DATA_RETENTION_TIME_IN_DAYS = 5;

-- Storage split: active vs Time Travel vs Fail-safe vs retained for clones
SELECT table_name, active_bytes, time_travel_bytes, failsafe_bytes, retained_for_clone_bytes
FROM PREP_DB.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE table_schema = 'CORE' AND table_dropped IS NULL
ORDER BY active_bytes DESC;


/* =============================================================================
   16  ZERO-COPY CLONING
   ============================================================================= */
CREATE OR REPLACE TABLE orders_dev CLONE orders;                      -- metadata only, instant
UPDATE orders_dev SET amount = amount * 2 WHERE order_id <= 100;      -- only changed partitions now cost storage
SELECT SUM(amount) FROM orders;
SELECT SUM(amount) FROM orders_dev;

-- Permanent -> transient clone is allowed (transient -> permanent is not)
CREATE OR REPLACE TRANSIENT TABLE orders_scratch CLONE orders;

-- Clone a whole database (schemas, tables, views, file formats, sequences...).
-- Pipes on internal stages and internal named stages are NOT cloned.
CREATE OR REPLACE DATABASE PREP_DB_CLONE CLONE PREP_DB;
SHOW SCHEMAS IN DATABASE PREP_DB_CLONE;
SHOW STAGES IN SCHEMA PREP_DB_CLONE.CORE;     -- classic behavior: stg_internal is absent
SHOW PIPES  IN SCHEMA PREP_DB_CLONE.CORE;     -- p_orders is absent (it references an internal stage)
SHOW FILE FORMATS IN SCHEMA PREP_DB_CLONE.CORE;
DROP DATABASE PREP_DB_CLONE;

USE SCHEMA PREP_DB.CORE;


/* =============================================================================
   17  RBAC: ROLES, GRANTS, FUTURE GRANTS, MANAGED ACCESS
   ============================================================================= */
USE ROLE USERADMIN;                                -- creates users and roles
CREATE ROLE IF NOT EXISTS PREP_ANALYST  COMMENT = 'read-only analyst';
CREATE ROLE IF NOT EXISTS PREP_ENGINEER COMMENT = 'engineer, inherits analyst';
GRANT ROLE PREP_ANALYST  TO ROLE PREP_ENGINEER;    -- hierarchy: engineer inherits analyst
GRANT ROLE PREP_ENGINEER TO ROLE SYSADMIN;         -- best practice: roll custom roles up to SYSADMIN

USE ROLE SECURITYADMIN;                            -- MANAGE GRANTS
GRANT USAGE ON WAREHOUSE PREP_WH TO ROLE PREP_ANALYST;
GRANT USAGE ON DATABASE  PREP_DB TO ROLE PREP_ANALYST;
GRANT USAGE ON SCHEMA    PREP_DB.CORE TO ROLE PREP_ANALYST;
GRANT SELECT ON ALL TABLES    IN SCHEMA PREP_DB.CORE TO ROLE PREP_ANALYST;  -- existing
GRANT SELECT ON FUTURE TABLES IN SCHEMA PREP_DB.CORE TO ROLE PREP_ANALYST;  -- new ones
GRANT SELECT ON ALL VIEWS     IN SCHEMA PREP_DB.CORE TO ROLE PREP_ANALYST;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA PREP_DB.CORE TO ROLE PREP_ENGINEER;
GRANT OPERATE ON WAREHOUSE PREP_WH TO ROLE PREP_ENGINEER;   -- suspend/resume, not resize

-- Grant the analyst role to yourself (dynamic SQL, because the user name varies)
SET grant_sql = 'GRANT ROLE PREP_ANALYST TO USER "' || CURRENT_USER() || '"';
EXECUTE IMMEDIATE $grant_sql;

SHOW GRANTS TO ROLE PREP_ANALYST;
SHOW GRANTS OF ROLE PREP_ANALYST;
SHOW FUTURE GRANTS IN SCHEMA PREP_DB.CORE;

-- Test as the analyst
USE ROLE PREP_ANALYST;
USE WAREHOUSE PREP_WH;
SELECT COUNT(*) FROM PREP_DB.CORE.customers;
-- EXPECTED ERROR: analyst has no INSERT privilege
-- INSERT INTO PREP_DB.CORE.customers (customer_id) VALUES (-1);

-- Secondary roles: use privileges from all granted roles at once
USE SECONDARY ROLES ALL;
SELECT CURRENT_ROLE(), CURRENT_SECONDARY_ROLES();
USE SECONDARY ROLES NONE;

-- Managed access schema: only the schema owner or MANAGE GRANTS can grant
USE ROLE SYSADMIN;
CREATE SCHEMA IF NOT EXISTS PREP_DB.SECURE_CORE WITH MANAGED ACCESS;
SHOW SCHEMAS LIKE 'SECURE_CORE' IN DATABASE PREP_DB;   -- options = MANAGED ACCESS
USE SCHEMA PREP_DB.CORE;


/* =============================================================================
   18  NETWORK POLICY (created only, NOT applied, so you can't lock yourself out)
   ============================================================================= */
USE ROLE SECURITYADMIN;
CREATE OR REPLACE NETWORK POLICY NP_PREP_DEMO
  ALLOWED_IP_LIST = ('0.0.0.0/0')
  BLOCKED_IP_LIST = ('192.0.2.10')            -- blocked list wins over allowed list
  COMMENT = 'demo only - not applied';
DESC NETWORK POLICY NP_PREP_DEMO;
-- Applying it (user level overrides account level):
-- ALTER USER <some_test_user> SET NETWORK_POLICY = NP_PREP_DEMO;
-- ALTER ACCOUNT SET NETWORK_POLICY = NP_PREP_DEMO;   -- careful!
USE ROLE SYSADMIN;


/* =============================================================================
   19  COLUMN / ROW SECURITY, TAGS, CLASSIFICATION   >>> [ENTERPRISE+] <<<
   Uncomment this whole block on Enterprise or higher.
   =============================================================================
USE ROLE SYSADMIN;
USE SCHEMA PREP_DB.CORE;

-- Dynamic data masking
CREATE OR REPLACE MASKING POLICY mask_email AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PREP_ENGINEER') THEN val
       ELSE REGEXP_REPLACE(val, '.+@', '*****@') END;
ALTER TABLE customers MODIFY COLUMN email SET MASKING POLICY mask_email;

-- Row access policy
CREATE OR REPLACE ROW ACCESS POLICY rap_region AS (region STRING) RETURNS BOOLEAN ->
  IS_ROLE_IN_SESSION('PREP_ENGINEER') OR region = 'NA';
ALTER TABLE customers ADD ROW ACCESS POLICY rap_region ON (region);

-- Compare views of the data (secondary roles off so only the primary role counts)
USE SECONDARY ROLES NONE;
USE ROLE PREP_ANALYST;
SELECT region, COUNT(*), MIN(email) FROM PREP_DB.CORE.customers GROUP BY region;   -- NA only, masked
USE ROLE SYSADMIN;   -- SYSADMIN inherits PREP_ENGINEER
SELECT region, COUNT(*), MIN(email) FROM PREP_DB.CORE.customers GROUP BY region;   -- all regions, clear

-- Object tagging and tag-based masking
CREATE OR REPLACE TAG pii_type ALLOWED_VALUES 'email', 'name', 'phone';
CREATE OR REPLACE TAG cost_center;
ALTER TABLE customers MODIFY COLUMN name SET TAG pii_type = 'name';
ALTER WAREHOUSE PREP_WH SET TAG PREP_DB.CORE.cost_center = 'training';
SELECT SYSTEM$GET_TAG('PREP_DB.CORE.pii_type', 'PREP_DB.CORE.customers.name', 'COLUMN');
SELECT * FROM TABLE(PREP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('PREP_DB.CORE.customers', 'TABLE'));

CREATE OR REPLACE MASKING POLICY mask_string_by_tag AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PREP_ENGINEER') THEN val ELSE '***' END;
ALTER TAG pii_type SET MASKING POLICY mask_string_by_tag;   -- every STRING column tagged pii_type is masked

-- Data classification
-- SELECT SYSTEM$CLASSIFY('PREP_DB.CORE.customers', {'auto_tag': false});

-- Policy references
SELECT * FROM TABLE(PREP_DB.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'PREP_DB.CORE.customers', REF_ENTITY_DOMAIN => 'TABLE'));

-- Undo
ALTER TAG pii_type UNSET MASKING POLICY mask_string_by_tag;
ALTER TABLE customers MODIFY COLUMN email UNSET MASKING POLICY;
ALTER TABLE customers DROP ROW ACCESS POLICY rap_region;
*/


/* =============================================================================
   20  STREAMS AND TASKS
   ============================================================================= */
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;        -- needed to RESUME / EXECUTE tasks
-- For serverless tasks also: GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE SYSADMIN;
USE ROLE SYSADMIN;
USE SCHEMA PREP_DB.CORE;
USE WAREHOUSE PREP_WH;

CREATE OR REPLACE STREAM orders_stream ON TABLE orders;                  -- standard (delta)
CREATE OR REPLACE STREAM orders_append ON TABLE orders APPEND_ONLY = TRUE;

-- Generate changes
INSERT INTO orders (order_id, customer_id, order_date, amount, status)
  VALUES (100001, 1, CURRENT_DATE(), 99.99, 'NEW'), (100002, 2, CURRENT_DATE(), 15.00, 'NEW');
SET ins_qid = LAST_QUERY_ID();
UPDATE orders SET status = 'SHIPPED' WHERE order_id = 100001;
DELETE FROM orders WHERE order_id = 20;

-- Read the stream (SELECT does NOT advance the offset)
SELECT order_id, status, METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID
FROM orders_stream ORDER BY order_id;
SELECT order_id, METADATA$ACTION FROM orders_append;           -- inserts only
SELECT SYSTEM$STREAM_HAS_DATA('ORDERS_STREAM');
SHOW STREAMS LIKE 'ORDERS_%';                                  -- stale_after column

-- Task that consumes the stream
CREATE OR REPLACE TABLE order_audit (
  order_id NUMBER, status STRING, action STRING, is_update BOOLEAN, captured_at TIMESTAMP_LTZ);

CREATE OR REPLACE TASK t_capture_orders
  WAREHOUSE = PREP_WH
  SCHEDULE  = '60 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('ORDERS_STREAM')     -- skipped (no warehouse start) when empty
AS
  INSERT INTO order_audit
  SELECT order_id, status, METADATA$ACTION, METADATA$ISUPDATE, CURRENT_TIMESTAMP()
  FROM orders_stream;

CREATE OR REPLACE TASK t_after_capture
  WAREHOUSE = PREP_WH
  AFTER t_capture_orders                          -- child task: no SCHEDULE
AS
  DELETE FROM order_audit WHERE captured_at < DATEADD(day, -30, CURRENT_TIMESTAMP());

SHOW TASKS;                                       -- state = suspended (tasks start suspended)

EXECUTE TASK t_capture_orders;                    -- run the root once, now (asynchronous)

-- Wait ~30-60 s, then:
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(RESULT_LIMIT => 10))
ORDER BY scheduled_time DESC;
SELECT * FROM order_audit ORDER BY order_id;
SELECT COUNT(*) AS remaining_in_stream FROM orders_stream;    -- 0 after the task consumed it

-- To run on schedule: resume children first, then the root (left commented to avoid spend)
-- ALTER TASK t_after_capture RESUME;
-- ALTER TASK t_capture_orders RESUME;
-- ...and later:
-- ALTER TASK t_capture_orders SUSPEND;

-- CHANGES clause: read change data without a stream. The start point must be after
-- change tracking was enabled, which happened when the first stream was created above.
SELECT order_id, status, METADATA$ACTION, METADATA$ISUPDATE
FROM orders CHANGES (INFORMATION => DEFAULT) AT (STATEMENT => $ins_qid)
ORDER BY order_id;


/* =============================================================================
   21  DYNAMIC TABLES
   ============================================================================= */
CREATE OR REPLACE DYNAMIC TABLE dt_customer_revenue
  TARGET_LAG = '1 hour'
  WAREHOUSE  = PREP_WH
AS
SELECT c.customer_id, c.region, COUNT(o.order_id) AS orders, SUM(o.amount) AS revenue
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.region;

SELECT * FROM dt_customer_revenue ORDER BY revenue DESC NULLS LAST LIMIT 5;
SHOW DYNAMIC TABLES LIKE 'DT_%';                    -- target_lag, refresh_mode, scheduling_state

ALTER DYNAMIC TABLE dt_customer_revenue REFRESH;    -- manual refresh
SELECT name, state, refresh_action, refresh_trigger, data_timestamp
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'PREP_DB.CORE.DT_CUSTOMER_REVENUE'))
ORDER BY data_timestamp DESC;

-- EXPECTED ERROR: DML isn't allowed on dynamic tables
-- DELETE FROM dt_customer_revenue;

ALTER DYNAMIC TABLE dt_customer_revenue SUSPEND;    -- stop scheduled refreshes (cost control)


/* =============================================================================
   22  UDFs, UDTFs, STORED PROCEDURES, SNOWPARK
   ============================================================================= */
-- SQL scalar UDF
CREATE OR REPLACE FUNCTION f_tax(amount NUMBER(10,2))
  RETURNS NUMBER(10,2)
  AS 'amount * 0.18';

-- JavaScript UDF (arguments are UPPERCASE inside JS)
CREATE OR REPLACE FUNCTION f_js_double(x FLOAT)
  RETURNS FLOAT
  LANGUAGE JAVASCRIPT
  AS 'return X * 2;';

-- Python UDF (standard library only, no Anaconda packages needed)
CREATE OR REPLACE FUNCTION f_py_initials(name STRING)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  HANDLER = 'run'
AS
$$
def run(name):
    if name is None:
        return None
    return ''.join(p[0] for p in name.split('_') if p).upper()
$$;

SELECT order_id, amount, f_tax(amount) AS tax, f_js_double(amount::FLOAT) AS doubled
FROM orders LIMIT 5;
SELECT name, f_py_initials(name) FROM customers LIMIT 5;

-- SQL UDTF (table function)
CREATE OR REPLACE FUNCTION f_orders_for(cid NUMBER)
  RETURNS TABLE (order_id NUMBER, order_date DATE, amount NUMBER(10,2))
AS
$$
  SELECT order_id, order_date, amount FROM PREP_DB.CORE.orders WHERE customer_id = cid
$$;
SELECT * FROM TABLE(f_orders_for(42)) ORDER BY order_date DESC;

-- Secure UDF (definition hidden; shareable)
CREATE OR REPLACE SECURE FUNCTION f_secure_bucket(amount NUMBER(10,2))
  RETURNS STRING
  AS 'CASE WHEN amount >= 250 THEN ''HIGH'' ELSE ''LOW'' END';
SELECT f_secure_bucket(300), f_secure_bucket(10);

-- Stored procedure (Snowflake Scripting). It can run DDL and DML, and is invoked with CALL.
CREATE OR REPLACE PROCEDURE sp_archive_returned(days_back NUMBER)
  RETURNS STRING
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  CREATE TABLE IF NOT EXISTS orders_archive LIKE orders;
  INSERT INTO orders_archive
    SELECT * FROM orders
    WHERE status = 'RETURNED'
      AND order_date < DATEADD(day, -1 * :days_back, CURRENT_DATE());
  n := SQLROWCOUNT;
  RETURN 'Archived ' || n || ' rows';
END;
$$;
CALL sp_archive_returned(180);

-- Anonymous Snowflake Scripting block
EXECUTE IMMEDIATE $$
DECLARE
  total NUMBER DEFAULT 0;
BEGIN
  FOR i IN 1 TO 5 DO
    total := total + i;
  END FOR;
  RETURN total;
END;
$$;

-- Snowpark (Python) stored procedure.
-- If you get an Anaconda terms error, an ORGADMIN must accept the terms in
-- Snowsight (Admin > Terms) first.
CREATE OR REPLACE PROCEDURE sp_snowpark_status_summary()
  RETURNS TABLE ()
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'run'
AS
$$
from snowflake.snowpark.functions import col, count, sum as sum_

def run(session):
    return (session.table("PREP_DB.CORE.ORDERS")
                   .group_by(col("STATUS"))
                   .agg(count(col("ORDER_ID")).alias("ORDERS"),
                        sum_(col("AMOUNT")).alias("REVENUE"))
                   .sort(col("STATUS")))
$$;
CALL sp_snowpark_status_summary();

SHOW USER FUNCTIONS LIKE 'F_%';
SHOW PROCEDURES LIKE 'SP_%';


/* =============================================================================
   23  PERFORMANCE: CACHES, CLUSTERING, QUERY HISTORY
   ============================================================================= */
-- Metadata cache: answered from micro-partition metadata (no table scan)
SELECT COUNT(*), MIN(order_id), MAX(order_id) FROM orders;

-- Result cache: run the IDENTICAL query twice. The 2nd shows "QUERY RESULT REUSE" in Query Profile.
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
SELECT status, COUNT(*) AS n, SUM(amount) AS revenue FROM orders GROUP BY status ORDER BY status;
SELECT status, COUNT(*) AS n, SUM(amount) AS revenue FROM orders GROUP BY status ORDER BY status;

-- Post-process the last result without re-running it
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE n > 1000;

-- Disable the result cache for honest benchmarking
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
SELECT status, COUNT(*) AS n, SUM(amount) AS revenue FROM orders GROUP BY status ORDER BY status;

-- Operator-level stats for the query just above (like the Query Profile)
SELECT * FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()));
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- Plan without executing
EXPLAIN SELECT * FROM orders WHERE order_date >= DATEADD(day, -7, CURRENT_DATE());

-- Clustering information (works even without a defined clustering key)
SELECT SYSTEM$CLUSTERING_INFORMATION('orders', '(order_date)');
SELECT SYSTEM$CLUSTERING_DEPTH('orders', '(order_date)');

-- Define and then remove a clustering key (Automatic Clustering is serverless and billed)
ALTER TABLE orders CLUSTER BY (order_date);
SHOW TABLES LIKE 'ORDERS';                       -- cluster_by, automatic_clustering columns
ALTER TABLE orders SUSPEND RECLUSTER;
ALTER TABLE orders DROP CLUSTERING KEY;

-- Pruning-friendly vs pruning-hostile predicates (compare partitions scanned in Query Profile)
SELECT COUNT(*) FROM orders WHERE order_date >= '2026-01-01' AND order_date < '2026-02-01';
SELECT COUNT(*) FROM orders WHERE TO_CHAR(order_date, 'YYYY-MM') = '2026-01';

-- Query tag for attribution, and recent history (INFORMATION_SCHEMA: real time, 7 days)
ALTER SESSION SET QUERY_TAG = 'prep-cookbook';
SELECT 1;
SELECT query_id, query_text, query_tag, warehouse_name, execution_status,
       total_elapsed_time, bytes_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION(RESULT_LIMIT => 20))
ORDER BY start_time DESC;
ALTER SESSION UNSET QUERY_TAG;


/* =============================================================================
   24  SEARCH OPTIMIZATION AND QUERY ACCELERATION   >>> [ENTERPRISE+] <<<
   =============================================================================
SELECT SYSTEM$ESTIMATE_SEARCH_OPTIMIZATION_COSTS('PREP_DB.CORE.customers');
ALTER TABLE customers ADD SEARCH OPTIMIZATION ON EQUALITY(email);
SHOW TABLES LIKE 'CUSTOMERS';     -- search_optimization, search_optimization_progress
SELECT * FROM customers WHERE email = 'customer42@example.com';
ALTER TABLE customers DROP SEARCH OPTIMIZATION;

ALTER WAREHOUSE PREP_WH SET ENABLE_QUERY_ACCELERATION = TRUE QUERY_ACCELERATION_MAX_SCALE_FACTOR = 4;
-- SELECT SYSTEM$ESTIMATE_QUERY_ACCELERATION('<query_id>');
ALTER WAREHOUSE PREP_WH SET ENABLE_QUERY_ACCELERATION = FALSE;
*/


/* =============================================================================
   25  RESOURCE MONITORS (ACCOUNTADMIN only)
   ============================================================================= */
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE RESOURCE MONITOR RM_PREP WITH
  CREDIT_QUOTA    = 10
  FREQUENCY       = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 75  PERCENT DO NOTIFY
           ON 90  PERCENT DO SUSPEND               -- lets running queries finish
           ON 100 PERCENT DO SUSPEND_IMMEDIATE;    -- cancels running queries

ALTER WAREHOUSE PREP_WH SET RESOURCE_MONITOR = RM_PREP;   -- one monitor per warehouse
SHOW RESOURCE MONITORS;
-- Account-level monitor (applies to all warehouses; doesn't cover serverless):
-- ALTER ACCOUNT SET RESOURCE_MONITOR = RM_PREP;


/* =============================================================================
   26  SECURE DATA SHARING (provider side)
   ============================================================================= */
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE SHARE PREP_SHARE COMMENT = 'demo share';
GRANT USAGE  ON DATABASE PREP_DB                            TO SHARE PREP_SHARE;
GRANT USAGE  ON SCHEMA   PREP_DB.CORE                       TO SHARE PREP_SHARE;
GRANT SELECT ON VIEW     PREP_DB.CORE.V_REGION_SALES_SECURE TO SHARE PREP_SHARE;
GRANT SELECT ON TABLE    PREP_DB.CORE.CUSTOMERS             TO SHARE PREP_SHARE;
-- EXPECTED ERROR: non-secure views can't be shared
-- GRANT SELECT ON VIEW PREP_DB.CORE.V_REGION_SALES TO SHARE PREP_SHARE;

SHOW SHARES LIKE 'PREP_SHARE';
DESC SHARE PREP_SHARE;

/* Needs a second account:
ALTER SHARE PREP_SHARE ADD ACCOUNTS = <orgname>.<consumer_account_name>;
-- Consumer side:
CREATE DATABASE PARTNER_PREP FROM SHARE <provider_org>.<provider_account>.PREP_SHARE;
GRANT IMPORTED PRIVILEGES ON DATABASE PARTNER_PREP TO ROLE SYSADMIN;

-- Reader account (provider pays its compute):
CREATE MANAGED ACCOUNT PREP_READER
  ADMIN_NAME = 'reader_admin', ADMIN_PASSWORD = '<Strong-Passw0rd!>', TYPE = READER;
SHOW MANAGED ACCOUNTS;
*/


/* =============================================================================
   27  UNSTRUCTURED DATA URLS
   ============================================================================= */
USE ROLE SYSADMIN;
USE SCHEMA PREP_DB.CORE;
ALTER STAGE stg_internal REFRESH;

SELECT relative_path,
       BUILD_SCOPED_FILE_URL(@stg_internal, relative_path) AS scoped_url,     -- 24 h, generating user only
       BUILD_STAGE_FILE_URL(@stg_internal, relative_path)  AS file_url,       -- permanent, role-checked
       GET_PRESIGNED_URL(@stg_internal, relative_path, 600) AS presigned_url  -- anyone, 10 min
FROM DIRECTORY(@stg_internal)
WHERE relative_path LIKE 'single/%';


/* =============================================================================
   28  GOVERNANCE: ACCOUNT_USAGE vs INFORMATION_SCHEMA, PARAMETERS
   ============================================================================= */
-- INFORMATION_SCHEMA: real time, this database only, no dropped objects
SELECT table_name, table_type, is_transient, row_count, bytes, retention_time, clustering_key
FROM PREP_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'CORE'
ORDER BY table_name;

-- ACCOUNT_USAGE: whole account, 365 days, includes dropped objects, 45 min - 3 h latency
USE ROLE ACCOUNTADMIN;

SELECT warehouse_name, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name ORDER BY credits DESC;

SELECT query_id, LEFT(query_text, 80) AS sql, warehouse_size, total_elapsed_time,
       partitions_scanned, partitions_total,
       bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage, queued_overload_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC
LIMIT 20;

SELECT event_timestamp, user_name, client_ip, reported_client_type, first_authentication_factor, is_success
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
ORDER BY event_timestamp DESC LIMIT 20;

SELECT table_catalog, table_schema, table_name, deleted   -- dropped tables appear here
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE table_catalog = 'PREP_DB'
ORDER BY deleted DESC NULLS LAST;

SELECT referencing_object_name, referencing_object_domain, referenced_object_name, referenced_object_domain
FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE referencing_database = 'PREP_DB';

SELECT service_type, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY service_type ORDER BY credits DESC;

/* >>> [ENTERPRISE+] <<<  Access history (column-level lineage)
SELECT query_start_time, user_name, direct_objects_accessed, base_objects_accessed, objects_modified
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC LIMIT 20;
*/

-- Let a non-admin role read ACCOUNT_USAGE
GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE PREP_ENGINEER;
-- or all-or-nothing: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE PREP_ENGINEER;

-- Parameters and their hierarchy
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
ALTER SESSION SET TIMEZONE = 'UTC';
SHOW PARAMETERS LIKE 'TIMEZONE' IN SESSION;          -- level = SESSION
ALTER SESSION UNSET TIMEZONE;
SHOW PARAMETERS LIKE '%RETENTION%' IN ACCOUNT;       -- DATA_RETENTION_TIME_IN_DAYS, MIN_DATA_RETENTION_TIME_IN_DAYS
SHOW PARAMETERS LIKE 'MAX_DATA_EXTENSION_TIME_IN_DAYS' IN ACCOUNT;


/* =============================================================================
   29  REPLICATION AND FAILOVER   >>> [BUSINESS CRITICAL+] for failover <<<
   Reference only: needs a second account in your organization, with
   replication enabled by ORGADMIN.
   =============================================================================
-- ORGADMIN enables replication on both accounts:
USE ROLE ORGADMIN;
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER('<org>.<source_acct>', 'ENABLE_ACCOUNT_DATABASE_REPLICATION', 'true');

-- [Standard+] replication group (databases and shares)
USE ROLE ACCOUNTADMIN;
CREATE REPLICATION GROUP RG_PREP
  OBJECT_TYPES = DATABASES, SHARES
  ALLOWED_DATABASES = PREP_DB
  ALLOWED_SHARES = PREP_SHARE
  ALLOWED_ACCOUNTS = <org>.<target_acct>
  REPLICATION_SCHEDULE = '60 MINUTE';

-- [Business Critical+] failover group (can be promoted), plus account objects
CREATE FAILOVER GROUP FG_PREP
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES, RESOURCE MONITORS
  ALLOWED_DATABASES = PREP_DB
  ALLOWED_ACCOUNTS = <org>.<target_acct>
  REPLICATION_SCHEDULE = '10 MINUTE';

-- On the target account:
CREATE FAILOVER GROUP FG_PREP AS REPLICA OF <org>.<source_acct>.FG_PREP;
ALTER FAILOVER GROUP FG_PREP REFRESH;
ALTER FAILOVER GROUP FG_PREP PRIMARY;                 -- failover

-- [Business Critical+] Client Redirect
CREATE CONNECTION PREP_CONN;
ALTER CONNECTION PREP_CONN ENABLE FAILOVER TO ACCOUNTS <org>.<target_acct>;
*/


/* =============================================================================
   99  CLEANUP (uncomment and run when you're done)
   =============================================================================
USE ROLE ACCOUNTADMIN;
ALTER TASK IF EXISTS PREP_DB.CORE.T_CAPTURE_ORDERS SUSPEND;
ALTER PIPE IF EXISTS PREP_DB.CORE.P_ORDERS SET PIPE_EXECUTION_PAUSED = TRUE;
DROP SHARE IF EXISTS PREP_SHARE;
DROP DATABASE IF EXISTS PREP_DB;
DROP DATABASE IF EXISTS PREP_DB_CLONE;
DROP WAREHOUSE IF EXISTS PREP_WH;
DROP RESOURCE MONITOR IF EXISTS RM_PREP;
DROP NETWORK POLICY IF EXISTS NP_PREP_DEMO;
REVOKE EXECUTE TASK ON ACCOUNT FROM ROLE SYSADMIN;
USE ROLE USERADMIN;
DROP ROLE IF EXISTS PREP_ENGINEER;
DROP ROLE IF EXISTS PREP_ANALYST;
-- Note: dropped databases stay in Time Travel (UNDROP-able) for their retention period.
*/
