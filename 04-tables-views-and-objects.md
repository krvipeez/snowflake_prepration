# 04 — Tables, Views, and Objects

**Exam domains:** 1 (Architecture) and 4 (Loading)

## 4.1 Object hierarchy

```
ORGANIZATION
└── ACCOUNT
    ├── Users, Roles, Warehouses, Resource monitors, Integrations,
    │   Network policies, Shares, Databases            (account-level objects)
    └── DATABASE
        └── SCHEMA
            ├── Tables, Views, Materialized views, Dynamic tables
            ├── Stages, File formats, Pipes, Streams, Tasks
            ├── Sequences, UDFs, Stored procedures, Alerts
            └── Policies (masking, row access, ...), Tags, Secrets, Network rules
```

- The fully qualified name is `database.schema.object`. The pair `database.schema` is called the **namespace**.
- Every database contains `INFORMATION_SCHEMA` (read-only) and, by default, a `PUBLIC` schema.
- **Unquoted identifiers** are case-insensitive and stored in **UPPERCASE**. **Double-quoted identifiers** are case-sensitive, and `"MyTable"` is a different object from `MYTABLE`. The maximum identifier length is **255 characters**.

> **Exam trap:** `CREATE TABLE "orders"` creates a lowercase, case-sensitive name. Afterwards `SELECT * FROM orders` fails, because it looks for `ORDERS`.

## 4.2 Table types

| Type | Persists after session? | Time Travel (days) | Fail-safe | Visible to other sessions | Typical use | Edition |
|---|---|---|---|---|---|---|
| **Permanent** (default) | Yes | 0–1 (Standard); **0–90** ([Enterprise+]) | **7 days** | Yes | Production data | [Standard+] |
| **Transient** | Yes | **0–1** | **None** | Yes | Staging or derived data that can be rebuilt | [Standard+] |
| **Temporary** | **No**, dropped at session end | **0–1** | **None** | **No** | Session-scoped scratch work | [Standard+] |
| **External** | Metadata only; data stays in your cloud storage | None | None | Yes | Querying a data lake in place (read-only) | [Standard+] |
| **Dynamic** | Yes | Like permanent | Yes | Yes | Declarative pipelines (chapter 11) | [Standard+] |
| **Iceberg** | Yes; data in your external volume in Iceberg format | Snowflake-managed catalog: yes | Snowflake-managed: no Fail-safe on your storage (check the docs) | Yes | Open table format and interoperability | [Standard+] |
| **Hybrid** | Yes; row store plus column store | Yes | Yes | Yes | Transactional (Unistore) workloads with enforced PK and indexes | [Standard+], region-limited, **not in trials** |
| **Event** | Yes | | | Yes | Logs and traces from UDFs and procedures | [Standard+] |

```sql
CREATE TABLE        t_perm  (id INT);                                     -- permanent
CREATE TRANSIENT TABLE t_tr (id INT) DATA_RETENTION_TIME_IN_DAYS = 0;
CREATE TEMPORARY TABLE t_tmp (id INT);
CREATE TRANSIENT DATABASE staging_db;     -- all schemas/tables inside are transient
```

> **Exam trap:** **Transient and temporary tables have no Fail-safe** and at most **1 day** of Time Travel, **even in Enterprise edition**.

> **Exam trap:** You **cannot convert** a permanent table to transient, or the other way round, with `ALTER`. You must create a new table and copy the data into it, for example with `CREATE TRANSIENT TABLE ... AS SELECT`.

> **Exam trap:** A **temporary table can have the same name** as a permanent table in the same schema. Within that session the temporary table **takes precedence**, which hides the permanent one.

> **Exam trap:** In a **transient database or schema**, every table created inside is transient. You can't create a permanent table there.

### External tables [Standard+]

- These are read-only tables over files in an **external stage**. Each row exposes a `VALUE` column (VARIANT), plus pseudo-columns such as `METADATA$FILENAME`.
- You can define **virtual columns** and **partition columns** derived from the file path to enable pruning.
- Metadata can be refreshed automatically (cloud event notifications) or manually with `ALTER EXTERNAL TABLE ... REFRESH`.
- They are slower than native tables. A **materialized view** over an external table [Enterprise+] can speed them up.

## 4.3 View types

| Type | Stored results? | Definition visible to non-owners? | Optimizer shortcuts | Can be shared? | Edition |
|---|---|---|---|---|---|
| **Standard view** | No | Yes (`GET_DDL`, `SHOW VIEWS`) | All | **No**, not directly | [Standard+] |
| **Secure view** | No | **No**, hidden from non-owners | Some optimizations disabled to prevent data leakage, so it can be slower | **Yes** | [Standard+] |
| **Materialized view** | **Yes**, maintained automatically | Yes | Results precomputed | No (use a secure MV) | **[Enterprise+]** |
| **Secure materialized view** | Yes | No | | **Yes** | **[Enterprise+]** |
| **Recursive view** | No | Yes | | | [Standard+] |

```sql
CREATE SECURE VIEW v_sales_secure AS SELECT region, SUM(amount) amt FROM sales GROUP BY region;
CREATE MATERIALIZED VIEW mv_daily AS
  SELECT order_date, COUNT(*) n, SUM(amount) amt FROM sales GROUP BY order_date;   -- [Enterprise+]
SHOW VIEWS;   -- IS_SECURE and IS_MATERIALIZED columns
```

### Materialized view limitations [Enterprise+]

- Can reference **only one table**: no joins, and no self-joins.
- No window functions, `HAVING`, `ORDER BY`, `LIMIT`, UDFs, or non-deterministic functions. Only a limited set of aggregates is allowed.
- **Cannot** query another view or a materialized view, or a dynamic table.
- Maintenance is **serverless** and billed in credits. Results are **always current**: if the background refresh is behind, Snowflake combines the MV with the base-table changes at query time.
- The optimizer can **automatically rewrite** queries against the base table to use the MV.
- DML **cannot** be run directly against an MV.

> **Exam trap:** An MV that's out of date **still returns current data**. Snowflake does not serve stale MV results.

> **Exam trap:** Only **secure** views (and secure MVs and secure UDFs) can be added to a share.

## 4.4 Stages

A **stage** is a location for data files used to load or unload data.

| Stage | Reference | Created by | Who can use it | Can set file format? | Can be dropped or altered? | Notes |
|---|---|---|---|---|---|---|
| **User stage** | `@~` | Automatically, one per user | Only that user | No | No | Can't be accessed by other users |
| **Table stage** | `@%table_name` | Automatically, one per table | Users with privileges on the table | Yes, via `ALTER TABLE ... SET STAGE_FILE_FORMAT` | No | Loads only into that table. **No transformations during load.** |
| **Named internal stage** | `@stage_name` | `CREATE STAGE` | Any role with privileges | Yes | Yes | Most flexible internal option; schema object |
| **Named external stage** | `@stage_name` | `CREATE STAGE ... URL=` | Any role with privileges | Yes | Yes | Points at S3, Azure Blob, or GCS; uses a **storage integration** (recommended) or credentials |

```sql
CREATE STAGE my_int_stage
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- external: integration created by ACCOUNTADMIN (or a role with CREATE INTEGRATION)
CREATE STORAGE INTEGRATION s3_int
  TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3' ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake_access'
  STORAGE_ALLOWED_LOCATIONS = ('s3://my-bucket/landing/');
CREATE STAGE my_ext_stage URL = 's3://my-bucket/landing/' STORAGE_INTEGRATION = s3_int;

LIST @my_int_stage;  REMOVE @my_int_stage/old/;
```

> **Exam trap:** `PUT` and `GET` work with **internal** stages only. Files reach external stages through the cloud provider's own tools.

> **Exam trap:** A **storage integration** stores a generated IAM entity (an identity on the cloud side) rather than secret keys, so users never handle cloud credentials. It is an account-level object.

### Directory tables [Standard+]

A directory table is an implicit table on a stage that catalogs its files (`RELATIVE_PATH`, `SIZE`, `LAST_MODIFIED`, `MD5`, `ETAG`, `FILE_URL`). You enable it with `DIRECTORY = (ENABLE = TRUE)` and query it with `SELECT * FROM DIRECTORY(@stage)`. Refresh it with `ALTER STAGE ... REFRESH`; external stages can also refresh automatically. Directory tables are the foundation for **unstructured data** (chapter 6).

## 4.5 File formats

A **file format** is a named, reusable set of parsing options. It's a schema object.

| `TYPE` | Load | Unload | Notes |
|---|:-:|:-:|---|
| `CSV` (any delimited text) | ✔ | ✔ | `FIELD_DELIMITER`, `SKIP_HEADER`, `FIELD_OPTIONALLY_ENCLOSED_BY`, `NULL_IF`, `EMPTY_FIELD_AS_NULL`, `ERROR_ON_COLUMN_COUNT_MISMATCH`, `PARSE_HEADER` |
| `JSON` | ✔ | ✔ (NDJSON) | `STRIP_OUTER_ARRAY`, `STRIP_NULL_VALUES`, `ALLOW_DUPLICATE` |
| `PARQUET` | ✔ | ✔ | `BINARY_AS_TEXT`; Snappy compression by default on unload |
| `AVRO` | ✔ | | |
| `ORC` | ✔ | | |
| `XML` | ✔ | | `STRIP_OUTER_ELEMENT`; XML support is a preview or limited feature in some areas |

```sql
CREATE FILE FORMAT ff_csv TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"' NULL_IF = ('', 'NULL') COMPRESSION = AUTO;
CREATE FILE FORMAT ff_json TYPE = JSON STRIP_OUTER_ARRAY = TRUE;
```

**Precedence of file format options**, highest first:

1. Options in the **`COPY INTO`** statement
2. Options on the **stage** definition
3. Options on the **table** (stage file format of the table)

> **Exam trap:** Snowflake **unloads** only to CSV/TSV, JSON, and Parquet. Avro, ORC, and XML are **load-only**.

## 4.6 Other schema objects worth knowing

| Object | Purpose |
|---|---|
| **Sequence** | Generates unique numbers (`seq.NEXTVAL`). They are **not guaranteed gap-free**. `AUTOINCREMENT` / `IDENTITY` columns use sequences internally. |
| **Pipe** | Wraps a `COPY INTO` for Snowpipe (chapter 5) |
| **Stream** | Change tracking (chapter 11) |
| **Task** | Scheduled or triggered SQL (chapter 11) |
| **Alert** | Runs an action when a condition query returns rows |
| **Secret** | Stores credentials for external access integrations |
| **Masking / row access / aggregation / projection policy** | Governance (chapter 7) [Enterprise+] |
| **Tag** | Key-value metadata (chapter 12) [Enterprise+] |

## 4.7 Data types quick reference

| Category | Types | Notes |
|---|---|---|
| Numeric | `NUMBER(p,s)` (default `NUMBER(38,0)`), `INT` = `NUMBER(38,0)`, `FLOAT`/`DOUBLE` | `DECIMAL`, `NUMERIC`, `INTEGER` are synonyms |
| String | `VARCHAR` (alias `STRING`, `TEXT`), `BINARY` | The classic VARCHAR maximum is **16 MB** (16,777,216 bytes); newer releases raise this, so check the docs. Declaring a length smaller than the max gives **no** storage or performance benefit. |
| Boolean | `BOOLEAN` | |
| Date/time | `DATE`, `TIME`, `TIMESTAMP_NTZ`, `TIMESTAMP_LTZ`, `TIMESTAMP_TZ` | `TIMESTAMP` maps to `TIMESTAMP_NTZ` by default (`TIMESTAMP_TYPE_MAPPING`) |
| Semi-structured | `VARIANT`, `OBJECT`, `ARRAY` | Chapter 6 |
| Geospatial | `GEOGRAPHY`, `GEOMETRY` | |
| Vector | `VECTOR(FLOAT, n)` | AI and embedding workloads |

## Self-check

**1. Which table types have no Fail-safe?**
<details><summary>Answer</summary><b>Transient</b> and <b>temporary</b> tables. External tables also have none, since Snowflake doesn't hold their data.</details>

**2. Which stage cannot be referenced by other users, and has no file format setting?**
<details><summary>Answer</summary>The <b>user stage</b> (<code>@~</code>).</details>

**3. Can you apply a transformation (a SELECT) while loading from a table stage?**
<details><summary>Answer</summary>No. Table stages don't support transformations during load. Use a named stage instead.</details>

**4. Name two limitations of materialized views.**
<details><summary>Answer</summary>Any two of: they reference a single table (no joins), allow no window functions, HAVING, ORDER BY, LIMIT, or UDFs, can't reference other views, and need [Enterprise+].</details>

**5. Which file formats can Snowflake unload to?**
<details><summary>Answer</summary>CSV/TSV (delimited), JSON, and Parquet.</details>

**6. In what order are file format options applied when they're set in several places?**
<details><summary>Answer</summary>The COPY statement first, then the stage definition, then the table definition.</details>
