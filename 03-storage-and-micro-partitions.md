# 03 — Storage and Micro-partitions

**Exam domains:** 1 (Architecture) and 3 (Performance)

## 3.1 How Snowflake stores data

- All table data is automatically divided into **micro-partitions**: contiguous units of storage holding **50–500 MB of uncompressed data**. They are much smaller once compressed, around 16 MB on average. [Standard+]
- Data inside a micro-partition is stored **by column** (columnar), and each column is **compressed** independently. Snowflake picks the compression algorithm.
- Micro-partitions are **immutable**. An `UPDATE`, `DELETE`, or `MERGE` writes **new** micro-partitions and marks the old ones as no longer current. The old ones are what make Time Travel and Fail-safe possible.
- Partitioning is **automatic**, and follows the order in which the data is inserted or loaded. This is called **natural clustering**. Users do not define partitions.
- Snowflake has **no user-defined indexes** on standard tables. Pruning plus metadata do the job instead.

> **Exam trap:** You do **not** create or manage partitions in Snowflake. Options such as "PARTITION BY on CREATE TABLE" or "create an index" are distractors for standard tables. (Hybrid tables do support indexes, but they are a separate table type.)

> **Exam trap:** Constraints: only **NOT NULL** is enforced on standard tables. **PRIMARY KEY, UNIQUE, and FOREIGN KEY are informational only** and are not enforced. They are enforced on hybrid tables.

### Metadata kept per micro-partition

Cloud services keeps this metadata for every micro-partition:

| Metadata | Used for |
|---|---|
| Range of values per column (**MIN / MAX**) | Pruning |
| Number of **distinct values** per column | Optimization |
| Number of **NULLs** per column | Optimization, `COUNT` |
| Row count, byte size | Metadata-only queries, planning |

## 3.2 Pruning

**Pruning** means skipping micro-partitions that cannot contain matching rows, based on their MIN/MAX metadata.

- **Static pruning** comes from `WHERE` predicates on columns.
- **Dynamic (join) pruning** comes from join-filter values produced at runtime.
- The Query Profile `TableScan` operator shows **Partitions scanned** and **Partitions total**. If scanned is close to total, pruning is poor.

What prevents pruning:

| Pattern | Why |
|---|---|
| Wrapping the filter column in a function, e.g. `WHERE TO_CHAR(order_date,'YYYY') = '2024'` | MIN/MAX of the raw column can't be compared to the expression |
| Filtering on a column whose values are spread randomly across all partitions | Every partition's MIN/MAX range overlaps the predicate |
| Leading wildcards such as `LIKE '%abc'` | No useful range |
| Comparing to a sub-query result that is only known late | Static pruning isn't possible (dynamic pruning may still help) |

## 3.3 Clustering

### Clustering metrics

| Term | Meaning |
|---|---|
| **Overlap** | Number of micro-partitions whose value ranges overlap for a column |
| **Clustering depth** | Average depth of overlapping micro-partitions for the given columns. **Lower is better.** A populated table has a minimum of 1. |
| **Constant partition** | A micro-partition where MIN = MAX for the column. It can't be improved further. |

```sql
SELECT SYSTEM$CLUSTERING_INFORMATION('sales', '(order_date)');  -- JSON report
SELECT SYSTEM$CLUSTERING_DEPTH('sales', '(order_date)');        -- single number
```

`SYSTEM$CLUSTERING_INFORMATION` returns `cluster_by_keys`, `total_partition_count`, `total_constant_partition_count`, `average_overlaps`, `average_depth`, and `partition_depth_histogram`.

> **Exam trap:** You can call `SYSTEM$CLUSTERING_INFORMATION` on columns that are **not** a defined clustering key. Passing a column list lets you evaluate candidate keys.

### Clustering keys [Standard+]

A **clustering key** is one or more columns or expressions that Snowflake uses to co-locate rows. Once a key is defined, **Automatic Clustering** reclusters the table in the background using **serverless compute**, which is billed in credits.

```sql
ALTER TABLE sales CLUSTER BY (order_date, region);
ALTER TABLE sales CLUSTER BY (TO_DATE(event_ts), SUBSTR(sku, 1, 3));  -- expressions allowed
ALTER TABLE sales SUSPEND RECLUSTER;   -- pause automatic clustering
ALTER TABLE sales RESUME RECLUSTER;
ALTER TABLE sales DROP CLUSTERING KEY;
```

When a clustering key is worth it:

| Good candidate | Poor candidate |
|---|---|
| Very large tables, typically **multi-terabyte** with many micro-partitions | Small tables |
| Queries filter or join on the key columns frequently | Columns rarely used in filters |
| Query performance has degraded as the table has grown | Tables with very frequent DML (reclustering churn costs credits) |
| Table is queried far more than it is changed | Very high-cardinality keys such as UUIDs or exact timestamps. Use an expression like `TO_DATE(ts)` instead. |

Guidelines:

- Use **at most 3–4 columns** per key.
- Order columns from **lowest to highest cardinality**.
- Too-low cardinality (for example a boolean) gives little pruning. Too-high cardinality is expensive to maintain.

> **Exam trap:** Automatic Clustering is **serverless**. It doesn't use your warehouse, and **resource monitors cannot limit it**. Track it with `AUTOMATIC_CLUSTERING_HISTORY`.

> **Exam trap:** Manual reclustering (`ALTER TABLE ... RECLUSTER`) is **deprecated**. Automatic Clustering is the supported mechanism.

> **Exam trap:** Clustering changes micro-partitions, so it adds Time Travel and Fail-safe storage and **invalidates result-cache entries** for that table.

## 3.4 Search Optimization Service [Enterprise+]

A table-level property that builds and maintains a persistent **search access path**. It speeds up **highly selective lookups** that return a few rows from a big table.

| Supports | Example |
|---|---|
| Equality and `IN` predicates | `WHERE email = 'a@b.com'` |
| Substring and regex | `WHERE note LIKE '%timeout%'`, `RLIKE` (needs `ON SUBSTRING(col)`) |
| Fields in VARIANT, OBJECT, ARRAY | `WHERE v:device.id = 'X1'` |
| Geospatial functions | `ST_INTERSECTS(...)` |
| Selected scalar functions and conjunctions | Check the docs for the current list |

```sql
ALTER TABLE customers ADD SEARCH OPTIMIZATION;                       -- whole table
ALTER TABLE customers ADD SEARCH OPTIMIZATION ON EQUALITY(email), SUBSTRING(notes);
SELECT SYSTEM$ESTIMATE_SEARCH_OPTIMIZATION_COSTS('customers');
ALTER TABLE customers DROP SEARCH OPTIMIZATION;
```

- **Costs:** extra storage for the search access path, plus serverless compute to build and maintain it.
- **Privileges:** OWNERSHIP of the table, plus `ADD SEARCH OPTIMIZATION` on the schema.

## 3.5 Choosing a performance feature

| Feature | Best for | Maintained by | Edition |
|---|---|---|---|
| **Clustering key** | Range filters on large tables (dates, categories); improves pruning | Serverless Automatic Clustering | [Standard+] |
| **Search optimization** | Point lookups or needle-in-haystack queries returning few rows | Serverless | [Enterprise+] |
| **Materialized view** | Repeated expensive aggregations or projections on **one** table | Serverless | [Enterprise+] |
| **Query Acceleration Service** | Outlier queries with large scans and selective filters; offloads work to shared compute | Serverless, per query | [Enterprise+] |
| **Bigger warehouse** | Complex joins, sorts, spilling | Your warehouse | [Standard+] |
| **Result cache** | Exactly repeated queries on unchanged data | Automatic, free | [Standard+] |

## 3.6 Storage billing

- Billed on the **average compressed bytes** stored per month. That includes active data, **Time Travel** data, **Fail-safe** data, and files in **internal stages**.
- **Zero-copy clones** cost nothing extra until data diverges. After that, only the changed micro-partitions are billed.
- Pricing is either **on-demand** (per TB per month) or **capacity** (pre-purchased, discounted).
- Storage metrics are available in `TABLE_STORAGE_METRICS` with these columns: `ACTIVE_BYTES`, `TIME_TRAVEL_BYTES`, `FAILSAFE_BYTES`, `RETAINED_FOR_CLONE_BYTES`.

> **Exam trap:** Frequent updates on a table with a long Time Travel retention can make **Time Travel storage much larger than active storage**. Every changed micro-partition is kept for the full retention period, and then for 7 days of Fail-safe on permanent tables.

## Self-check

**1. What is the uncompressed size range of a micro-partition?**
<details><summary>Answer</summary><b>50–500 MB</b> uncompressed.</details>

**2. Which constraint does Snowflake enforce on standard tables?**
<details><summary>Answer</summary>Only <b>NOT NULL</b>. PRIMARY KEY, UNIQUE, and FOREIGN KEY are informational.</details>

**3. What does a high average clustering depth tell you?**
<details><summary>Answer</summary>Many micro-partitions overlap for those columns, so pruning will be poor. Lower depth is better.</details>

**4. Is Automatic Clustering controlled by resource monitors?**
<details><summary>Answer</summary>No. It is serverless, and resource monitors only control user-managed warehouses.</details>

**5. Which feature suits `WHERE customer_email = ?` lookups on a 5 TB table?**
<details><summary>Answer</summary>The <b>Search Optimization Service</b> [Enterprise+], ideally with <code>ON EQUALITY(customer_email)</code>.</details>

**6. Why might `WHERE YEAR(order_date) = 2024` scan more partitions than `WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'`?**
<details><summary>Answer</summary>Wrapping a column in a function can stop Snowflake comparing the predicate to MIN/MAX metadata. A plain range predicate on the raw column prunes reliably.</details>
