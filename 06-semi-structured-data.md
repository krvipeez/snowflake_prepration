# 06 — Semi-structured Data and Transformations

**Exam domain:** 5 (Data Transformations, 20%)

## 6.1 Semi-structured data types [Standard+]

| Type | Holds | Example literal |
|---|---|---|
| `VARIANT` | Any value, including OBJECT and ARRAY | `PARSE_JSON('{"a":1}')` |
| `OBJECT` | Key–value pairs; keys are strings, values are VARIANT | `OBJECT_CONSTRUCT('a',1,'b','x')` |
| `ARRAY` | Ordered list of VARIANT values | `ARRAY_CONSTRUCT(1,2,3)` |

- Supported input formats: **JSON, Avro, ORC, Parquet, XML**.
- The classic size limit for a single VARIANT value is **16 MB**. Newer releases raise this, so check the docs.
- When loading, Snowflake **automatically extracts frequently occurring paths into columnar sub-columns** where it can, so you get columnar performance and **pruning on JSON paths**. Paths with mixed types, or values stored as strings such as dates, may not be extracted.
- **Structured** types (for example `ARRAY(NUMBER)`, `OBJECT(name VARCHAR, age NUMBER)`, `MAP(VARCHAR, NUMBER)`) also exist. They're used mainly with Iceberg tables.

> **Exam trap:** A JSON `null` is **not** the same as SQL `NULL`. A JSON null is stored in VARIANT as the value `null`. `IS NULL` is false for it, and `IS_NULL_VALUE(v:x)` is true. The file format option `STRIP_NULL_VALUES = TRUE` removes JSON nulls at load time.

## 6.2 Querying VARIANT

```sql
-- given v = {"id":7,"Name":"Ann","address":{"city":"Pune"},"tags":["a","b"]}
SELECT v:id,                       -- 7        (VARIANT)
       v:Name::STRING,             -- Ann      (cast removes the double quotes)
       v:address.city::STRING,     -- dot notation for nested
       v['address']['city'],       -- bracket notation (needed for keys with spaces/special chars)
       v:tags[0]::STRING,          -- arrays are 0-based
       GET_PATH(v, 'address.city'),
       TYPEOF(v:tags),             -- ARRAY
       ARRAY_SIZE(v:tags)          -- 2
FROM raw;
```

> **Exam trap:** **Element names in paths are case-sensitive**: `v:Name` is not `v:name`. **Column names** such as `v` itself are case-insensitive as usual.

> **Exam trap:** Selecting `v:Name` without a cast returns `"Ann"` **with double quotes**, because it's a VARIANT string. Cast with `::STRING` (or `::VARCHAR`) to get `Ann`.

> **Exam trap:** Selecting a path that doesn't exist returns **NULL**, not an error.

### Useful functions

| Purpose | Functions |
|---|---|
| Parse and convert | `PARSE_JSON`, `TRY_PARSE_JSON`, `PARSE_XML`, `CHECK_JSON`, `TO_JSON`, `TO_VARIANT`, `AS_VARCHAR`, `AS_NUMBER` |
| Build | `OBJECT_CONSTRUCT` (**drops NULL values**), `OBJECT_CONSTRUCT_KEEP_NULL`, `OBJECT_INSERT`, `OBJECT_DELETE`, `ARRAY_CONSTRUCT`, `ARRAY_AGG`, `OBJECT_AGG`, `ARRAY_APPEND` |
| Inspect | `TYPEOF`, `IS_OBJECT`, `IS_ARRAY`, `IS_NULL_VALUE`, `OBJECT_KEYS`, `ARRAY_SIZE`, `ARRAY_CONTAINS` |
| Access | `GET`, `GET_PATH` (same as `:`), `XMLGET` |
| Flatten | `FLATTEN` (table function), `ARRAY_FLATTEN` (scalar) |

## 6.3 FLATTEN

`FLATTEN` is a **table function** that turns elements of an ARRAY or OBJECT into rows. Use it with `LATERAL` (or a comma join) to correlate with the source row.

```sql
SELECT r.v:id::INT   AS order_id,
       f.index       AS line_no,
       f.value:sku::STRING AS sku,
       f.value:qty::INT    AS qty
FROM raw_orders r,
     LATERAL FLATTEN(INPUT => r.v:lines) f;
```

### Output columns

| Column | Meaning |
|---|---|
| `SEQ` | Unique sequence number for each input record |
| `KEY` | Key name (for OBJECT elements); NULL for array elements |
| `PATH` | Path to the element |
| `INDEX` | Array position (for ARRAY elements); NULL for object keys |
| `VALUE` | The element value (VARIANT) |
| `THIS` | The element being flattened (its parent) |

### Arguments

| Argument | Default | Meaning |
|---|---|---|
| `INPUT` | (required) | Expression to flatten |
| `PATH` | | Path inside INPUT to flatten |
| `OUTER` | `FALSE` | `TRUE` emits one row (with NULLs) for empty or missing input, like a left outer join |
| `RECURSIVE` | `FALSE` | `TRUE` flattens all nested levels |
| `MODE` | `'BOTH'` | `'OBJECT'`, `'ARRAY'`, or `'BOTH'` |

> **Exam trap:** With `OUTER => FALSE` (the default), rows whose array is **empty or missing disappear** from the result. Use `OUTER => TRUE` to keep them.

> **Exam trap:** For nested arrays, **chain FLATTENs**: `LATERAL FLATTEN(INPUT => f1.value:children) f2`.

## 6.4 Core transformation SQL

### MERGE (upsert)

```sql
MERGE INTO dim_customer d
USING stg_customer s
  ON d.customer_id = s.customer_id
WHEN MATCHED AND s.is_deleted THEN DELETE
WHEN MATCHED THEN UPDATE SET d.email = s.email, d.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (customer_id, email, updated_at)
                      VALUES (s.customer_id, s.email, CURRENT_TIMESTAMP());
```

> **Exam trap:** If **several source rows match the same target row**, an `UPDATE`/`DELETE` MERGE is **non-deterministic**, and by default it **fails** (`ERROR_ON_NONDETERMINISTIC_MERGE = TRUE`). Deduplicate the source first, for example with QUALIFY.

### QUALIFY

`QUALIFY` filters on the result of a **window function**, the way `HAVING` filters on aggregates.

```sql
SELECT *
FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_ts DESC) = 1;   -- latest per customer
```

Evaluation order: `FROM → WHERE → GROUP BY → HAVING → WINDOW → QUALIFY → DISTINCT → ORDER BY → LIMIT`.

### Other transformation features

| Feature | Syntax / note |
|---|---|
| Window functions | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `FIRST_VALUE`, `SUM() OVER (...)`, `RATIO_TO_REPORT` |
| Multi-table insert | `INSERT ALL` (every matching `WHEN`) / `INSERT FIRST` (first matching `WHEN` only) |
| Overwrite | `INSERT OVERWRITE INTO t SELECT ...` truncates then inserts, in one transaction |
| Pivot | `PIVOT (SUM(amount) FOR status IN ('A','B'))`, `UNPIVOT (...)` |
| Grouping | `GROUP BY ROLLUP(...)`, `CUBE(...)`, `GROUPING SETS(...)`, `GROUP BY ALL` |
| CTEs | `WITH x AS (...)`, recursive `WITH RECURSIVE` |
| Safe casting | `TRY_CAST`, `TRY_TO_NUMBER`, `TRY_TO_DATE`: return NULL instead of an error |
| Conditional | `IFF`, `CASE`, `DECODE`, `COALESCE`, `NVL`, `NULLIF`, `ZEROIFNULL` |
| Sampling | `SAMPLE BERNOULLI (10)` / `ROW` (each row with p%); `SAMPLE SYSTEM (10)` / `BLOCK` (each micro-partition block with p%); `SAMPLE (100 ROWS)` (fixed count); `SEED (n)` / `REPEATABLE` for reproducibility (not with fixed-row samples) |
| Approximate | `APPROX_COUNT_DISTINCT` / `HLL` (HyperLogLog), `APPROX_TOP_K` (Space-Saving), `APPROX_PERCENTILE` (t-Digest), `MINHASH` + `APPROXIMATE_SIMILARITY` |

> **Exam trap:** `SAMPLE SYSTEM`/`BLOCK` is faster but less random than `BERNOULLI`/`ROW`, because it samples whole blocks.

> **Exam trap:** `APPROX_COUNT_DISTINCT` uses **HyperLogLog**, with an average relative error of about 1.6%. Expect the algorithm name in questions.

## 6.5 Unstructured data [Standard+]

Unstructured files (PDFs, images, audio) live on internal or external stages, usually with a **directory table**.

| URL type | Function | Lifetime | Who can use it |
|---|---|---|---|
| **Scoped URL** | `BUILD_SCOPED_FILE_URL(@stage, 'path')` | **24 hours** (it expires when the persisted query result expires) | Only the user who generated it; access is checked against the role |
| **File URL** | `BUILD_STAGE_FILE_URL(@stage, 'path')` | **Permanent** | Any role with the required privileges on the stage |
| **Pre-signed URL** | `GET_PRESIGNED_URL(@stage, 'path', expiration_secs)` | Configurable (default 3,600 s) | **Anyone** with the link; no Snowflake authentication needed |

```sql
SELECT relative_path,
       BUILD_SCOPED_FILE_URL(@docs_stage, relative_path) AS scoped_url,
       GET_PRESIGNED_URL(@docs_stage, relative_path, 600)  AS presigned_url
FROM DIRECTORY(@docs_stage);
```

Unstructured files are processed with UDFs or procedures (Python, Java) that read files through `SnowflakeFile`, with Snowpark, or with Cortex AI document functions.

> **Exam trap:** Use **pre-signed URLs** for tools outside Snowflake, such as BI dashboards showing images to users without Snowflake logins. Use **scoped URLs** for temporary, auditable, user-specific access. **File URLs** are for permanent, role-controlled access.

> **Tip:** For internal stages that hold unstructured data, create the stage with `ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')` (server-side encryption). With the default client-side encryption, pre-signed URLs return unreadable files.

## Self-check

**1. How do you remove the double quotes from `v:name` in a SELECT?**
<details><summary>Answer</summary>Cast it: <code>v:name::STRING</code>.</details>

**2. Which FLATTEN output column holds the array position?**
<details><summary>Answer</summary><b>INDEX</b>. KEY holds object keys, and VALUE holds the element.</details>

**3. A FLATTEN query drops customers whose `orders` array is empty. How do you keep them?**
<details><summary>Answer</summary>Use <code>FLATTEN(INPUT => ..., OUTER => TRUE)</code>.</details>

**4. What does QUALIFY filter on?**
<details><summary>Answer</summary>The results of window functions, after they're evaluated.</details>

**5. What happens by default when a MERGE has duplicate source rows matching one target row?**
<details><summary>Answer</summary>It raises an error, because <code>ERROR_ON_NONDETERMINISTIC_MERGE</code> defaults to TRUE.</details>

**6. Which URL type lets a person with no Snowflake account download a staged file for a limited time?**
<details><summary>Answer</summary>A <b>pre-signed URL</b> (<code>GET_PRESIGNED_URL</code>).</details>
