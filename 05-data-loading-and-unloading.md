# 05 — Data Loading and Unloading

**Exam domain:** 4 (Data Loading and Unloading, 10%). The topics also show up in domains 1 and 5.

## 5.1 Ways to get data in

| Method | Compute | Latency | Best for | Edition |
|---|---|---|---|---|
| **Bulk load: `COPY INTO <table>`** | Your virtual warehouse | Batch | Scheduled batch loads | [Standard+] |
| **Snowpipe** (`CREATE PIPE`) | Serverless | Micro-batch, about a minute | Continuous file arrival | [Standard+] |
| **Snowpipe Streaming** | Serverless | Seconds; row-level, no files | Streams from Kafka or apps through the SDK | [Standard+] |
| **Snowsight upload** | Your warehouse | Manual | Small one-off files | [Standard+] |
| **`INSERT` / CTAS** | Your warehouse | | Small inserts, transformations | [Standard+] |
| **External tables / Iceberg tables** | Query in place | | Data lake access without loading | [Standard+] |
| **Connectors and partners** | Varies | | Kafka, Spark, ETL tools, Openflow and other ingestion services | [Standard+] |

## 5.2 The bulk loading workflow

```
 local files ──PUT──▶ internal stage ─┐
                                      ├──COPY INTO <table>──▶ table
 cloud files ───────▶ external stage ─┘
```

### PUT (upload) and GET (download)

| | `PUT` | `GET` |
|---|---|---|
| Direction | Local file system → **internal** stage | **Internal** stage → local file system |
| Runs from | A client: SnowSQL, Snowflake CLI, drivers. **Not** a Snowsight worksheet. | Same |
| Key options | `AUTO_COMPRESS = TRUE` (gzip, default), `SOURCE_COMPRESSION`, `PARALLEL` (default 4), `OVERWRITE = FALSE` (default) | `PARALLEL`, `PATTERN` |
| Encryption | Files are encrypted automatically | Decrypted on download |

```bash
snowsql -q "PUT file:///data/orders_*.csv @my_int_stage/orders/ AUTO_COMPRESS=TRUE PARALLEL=8"
snowsql -q "GET @my_int_stage/unload/ file:///tmp/unload/"
```

> **Exam trap:** `PUT` **cannot** upload to an **external** stage, and `GET` cannot download from one.

> **Exam trap:** `PUT` compresses with **gzip by default**. Files that are already compressed (for example `.gz` or `.bz2`) are detected and not compressed again.

### COPY INTO &lt;table&gt;

```sql
COPY INTO orders
  FROM @my_int_stage/orders/
  FILE_FORMAT = (FORMAT_NAME = ff_csv)
  PATTERN = '.*orders_2024.*[.]csv[.]gz'
  ON_ERROR = 'SKIP_FILE'
  PURGE = TRUE;
```

| Option | Default | What it does |
|---|---|---|
| `FILES = ('a.csv','b.csv')` | | Explicit list, **up to 1,000 files** |
| `PATTERN = '<regex>'` | | Regular expression matched against the path |
| `ON_ERROR` | `ABORT_STATEMENT` for bulk COPY | See section 5.3 |
| `VALIDATION_MODE` | | Dry run; see section 5.4 |
| `SIZE_LIMIT = <bytes>` | | Stops loading new files once this much data has been loaded |
| `PURGE` | `FALSE` | Deletes files from the stage after a successful load |
| `FORCE` | `FALSE` | Reloads files even if load metadata says they were already loaded. **Can create duplicates.** |
| `LOAD_UNCERTAIN_FILES` | `FALSE` | Loads files whose load status is unknown (older than 64 days) |
| `MATCH_BY_COLUMN_NAME` | `NONE` | `CASE_SENSITIVE` / `CASE_INSENSITIVE`; maps columns by name (Parquet, Avro, ORC, JSON, CSV with `PARSE_HEADER`) |
| `ENFORCE_LENGTH` / `TRUNCATECOLUMNS` | `TRUE` / `FALSE` | Whether over-length strings fail or get truncated |
| `RETURN_FAILED_ONLY` | `FALSE` | Only report failed files in the output |

### Load metadata (deduplication)

- Snowflake keeps **load metadata for 64 days** for each table: file name, ETag or MD5, and load status.
- `COPY` **skips files it has already loaded** (same name and same contents) within those 64 days.
- If a file's `LAST_MODIFIED` date is **older than 64 days** and the load status is unknown, `COPY` skips it by default. `LOAD_UNCERTAIN_FILES = TRUE` or `FORCE = TRUE` overrides this.

> **Exam trap:** Running the same `COPY` twice loads the files **once**. The second run reports "0 files processed" or "LOAD_SKIPPED". Use `FORCE = TRUE` to reload, but expect duplicate rows.

> **Exam trap:** If a file is **modified** and staged again with the same name, it gets a new checksum and **will be loaded again**.

> **Exam trap:** Load metadata belongs to the **table**. A **cloned** table doesn't inherit it, and neither does a table recreated with `CREATE OR REPLACE`, so the same files can be loaded into either one again.

### Transformations allowed during COPY

`COPY INTO t FROM (SELECT ... FROM @stage)` supports:

- Column **reordering**, **omission**, and **casts**
- `$1`, `$2` positional references and `$1:field` for semi-structured data
- Some functions (for example `CONCAT`, `SUBSTR`, `TO_DATE`, `CURRENT_TIMESTAMP`)
- Pseudo-columns: `METADATA$FILENAME`, `METADATA$FILE_ROW_NUMBER`, `METADATA$FILE_LAST_MODIFIED`, `METADATA$START_SCAN_TIME`, `METADATA$FILE_CONTENT_KEY`

It does **not** support: `WHERE` filtering, `GROUP BY`, joins, `FLATTEN`, or `DISTINCT`. Load first, then transform.

```sql
COPY INTO raw_events (payload, src_file, loaded_at)
  FROM (SELECT $1, METADATA$FILENAME, CURRENT_TIMESTAMP() FROM @my_int_stage/events/)
  FILE_FORMAT = (TYPE = JSON STRIP_OUTER_ARRAY = TRUE);
```

> **Exam trap:** `VALIDATION_MODE` **cannot** be combined with a transforming `COPY` (one that uses a `SELECT` as its source).

## 5.3 ON_ERROR options

| Value | Behavior | Default for |
|---|---|---|
| `ABORT_STATEMENT` | Stops the whole load at the first error; nothing from the statement is loaded | **Bulk `COPY`** |
| `CONTINUE` | Skips bad rows and loads the rest | |
| `SKIP_FILE` | Skips any file that contains an error | **Snowpipe** |
| `SKIP_FILE_<n>` | Skips a file once it has `n` or more errors | |
| `'SKIP_FILE_<n>%'` | Skips a file once the share of error rows reaches `n`% | |

> **Exam trap:** The defaults differ: **COPY → `ABORT_STATEMENT`**, **Snowpipe → `SKIP_FILE`**.

## 5.4 Validating loads

| Tool | When | What it does |
|---|---|---|
| `VALIDATION_MODE = RETURN_<n>_ROWS` | Before loading | Parses and returns the first n rows if they're valid, otherwise the first error. **Loads nothing.** |
| `VALIDATION_MODE = RETURN_ERRORS` | Before loading | Returns all errors across the files. Loads nothing. |
| `VALIDATION_MODE = RETURN_ALL_ERRORS` | Before loading | Also includes errors from files loaded earlier with `ON_ERROR = CONTINUE` |
| `VALIDATE(table, JOB_ID => '<id>' \| '_last')` | After a `COPY` | Returns the rows rejected by a past `COPY` (14-day window) |
| `COPY_HISTORY` / `LOAD_HISTORY` | After | Status per file (chapter 12) |

```sql
COPY INTO orders FROM @my_int_stage/orders/ FILE_FORMAT=(FORMAT_NAME=ff_csv) VALIDATION_MODE = RETURN_ERRORS;
SELECT * FROM TABLE(VALIDATE(orders, JOB_ID => '_last'));
```

## 5.5 Snowpipe [Standard+]

A **pipe** is a named object that wraps a single `COPY INTO` statement. It loads files **automatically and continuously** using **serverless** compute.

```sql
CREATE PIPE p_orders AUTO_INGEST = TRUE AS
  COPY INTO orders FROM @my_ext_stage/orders/ FILE_FORMAT = (FORMAT_NAME = ff_csv);

SHOW PIPES;                                -- notification_channel column = SQS ARN for S3
SELECT SYSTEM$PIPE_STATUS('p_orders');
ALTER PIPE p_orders REFRESH;               -- queue files staged in the last 7 days
ALTER PIPE p_orders SET PIPE_EXECUTION_PAUSED = TRUE;
```

### How files are detected

| Trigger | Stage type | Mechanism |
|---|---|---|
| **Auto-ingest** (`AUTO_INGEST = TRUE`) | **External only** | Cloud event notifications: S3 → SQS (or SNS), Azure → Event Grid, GCS → Pub/Sub |
| **REST API** (`insertFiles` endpoint) | Internal **or** external | Your app calls the API with file names; authenticated with key-pair JWT |

### Bulk COPY vs Snowpipe

| | Bulk `COPY INTO` | Snowpipe |
|---|---|---|
| Compute | User-managed warehouse | **Serverless** (Snowflake-managed) |
| Billing | Warehouse uptime | Serverless compute for the load. Older pricing added a per-file overhead charge, and newer pricing is volume-based, so check current pricing. |
| Trigger | Manual or scheduled (tasks) | Event notification or REST call |
| Load history / dedup metadata | **64 days**, stored with the table | **14 days**, stored with the pipe |
| Default `ON_ERROR` | `ABORT_STATEMENT` | `SKIP_FILE` |
| Transactions | One transaction per `COPY` statement | Loads are combined or split into transactions based on file count and size |
| Load order | Not guaranteed | **Not guaranteed** |
| Resource monitor control | Yes, through the warehouse | **No** |

> **Exam trap:** Snowpipe **does not guarantee** that files load in the order they were staged.

> **Exam trap:** Running `CREATE OR REPLACE PIPE` **resets the pipe's load history**. With `ALTER PIPE ... REFRESH` afterwards, files may be loaded again.

> **Exam trap:** Changing a pipe's `COPY` statement requires recreating the pipe. Pause it first, check that the queue is empty, recreate it, then resume.

### Snowpipe Streaming

- Writes **rows**, not files, using the Snowflake Ingest SDK (Java), the Kafka connector in streaming mode, or newer high-performance APIs.
- Gives lower latency and lower cost for high-volume streams, with no stage needed.

## 5.6 File sizing and loading best practices

| Practice | Why |
|---|---|
| Aim for files of about **100–250 MB compressed** | Lets `COPY` parallelize across warehouse threads; keeps per-file overhead low |
| **Split** very large files and **combine** many tiny ones | One huge file can't be loaded in parallel; tiny files add overhead (especially in Snowpipe) |
| Stage Snowpipe files about **once per minute** | Balances latency against per-file cost |
| Organize stage paths by date or source, e.g. `/sales/2024/06/01/` | Lets `COPY` use path prefixes and PATTERN |
| Use a **dedicated warehouse** for loading | Isolates load workloads from BI |
| A larger warehouse only helps when there are **many files** | Each file is processed by one thread, so one big file on an XL is wasted |
| Prefer `ON_ERROR = ABORT_STATEMENT` while developing, then decide deliberately | Avoids silently dropping data |

## 5.7 Schema detection and evolution

```sql
SELECT * FROM TABLE(INFER_SCHEMA(LOCATION => '@my_int_stage/parquet/', FILE_FORMAT => 'ff_parquet'));

CREATE TABLE orders_pq USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(INFER_SCHEMA(LOCATION => '@my_int_stage/parquet/', FILE_FORMAT => 'ff_parquet')));

ALTER TABLE orders_pq SET ENABLE_SCHEMA_EVOLUTION = TRUE;   -- new columns added on load
```

`INFER_SCHEMA` supports Parquet, Avro, and ORC, plus JSON and CSV (CSV needs `PARSE_HEADER = TRUE`).

## 5.8 Querying staged files directly

```sql
SELECT $1, $2, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER
FROM @my_int_stage/orders/ (FILE_FORMAT => 'ff_csv', PATTERN => '.*[.]csv[.]gz')
LIMIT 10;
```

## 5.9 Unloading: COPY INTO &lt;location&gt;

```sql
COPY INTO @my_int_stage/unload/orders_
  FROM (SELECT * FROM orders WHERE order_date >= '2024-01-01')
  FILE_FORMAT = (TYPE = PARQUET)
  HEADER = TRUE
  MAX_FILE_SIZE = 104857600          -- 100 MB
  OVERWRITE = TRUE;

COPY INTO @my_int_stage/by_status/ FROM orders
  PARTITION BY ('status=' || status)
  FILE_FORMAT = (TYPE = PARQUET);
```

| Option | Default | Notes |
|---|---|---|
| `SINGLE` | `FALSE` | `TRUE` writes one file, up to `MAX_FILE_SIZE` |
| `MAX_FILE_SIZE` | **16 MB** (16,777,216 bytes) | Maximum **5 GB** per file for cloud storage stages |
| `HEADER` | `FALSE` | Writes column headers to CSV, and keeps column names in Parquet |
| `OVERWRITE` | `FALSE` | Replaces existing files with the same names |
| `PARTITION BY <expr>` | | Writes files into subfolders based on an expression |
| `INCLUDE_QUERY_ID` | `FALSE` | Adds the query ID to file names so concurrent unloads don't collide |
| Compression | gzip (CSV, JSON); Snappy (Parquet) | Set with `COMPRESSION` |
| File names | `data_<n>_<n>_<n>.<ext>` | Prefix taken from the path |

The unload destination can be an internal stage, an external stage, or (if allowed) a direct cloud URL. Afterwards, use `GET` to download from an internal stage.

> **Exam trap:** Unloading **JSON** requires the query to return a **single VARIANT or OBJECT column**. Build it with `OBJECT_CONSTRUCT(*)` or similar.

> **Exam trap:** By default an unload writes **multiple files in parallel**. You need `SINGLE = TRUE` to get one file.

## Self-check

**1. What is the default ON_ERROR for COPY, and for Snowpipe?**
<details><summary>Answer</summary>COPY: <b>ABORT_STATEMENT</b>. Snowpipe: <b>SKIP_FILE</b>.</details>

**2. How long is load metadata kept for bulk loads, and for Snowpipe?**
<details><summary>Answer</summary><b>64 days</b> for bulk COPY (with the table) and <b>14 days</b> for Snowpipe (with the pipe).</details>

**3. Which stages support Snowpipe auto-ingest?**
<details><summary>Answer</summary><b>External stages only</b> (S3, Azure, GCS event notifications). Internal stages need the REST API.</details>

**4. What does VALIDATION_MODE = RETURN_ERRORS load?**
<details><summary>Answer</summary>Nothing. It only validates the files and reports errors.</details>

**5. What is the recommended compressed file size for loading?**
<details><summary>Answer</summary>About <b>100–250 MB</b> compressed.</details>

**6. What is the default MAX_FILE_SIZE when unloading?**
<details><summary>Answer</summary><b>16 MB</b>. The maximum is 5 GB per file for cloud storage.</details>
