# 02 — Virtual Warehouses

**Exam domains:** 1 (Architecture) and 3 (Performance)

## 2.1 What a virtual warehouse is

A **virtual warehouse** is a named cluster of compute resources (CPU, memory, local SSD) that runs queries, DML, and data loading. [Standard+]

- It is needed for: `SELECT` that reads table data, DML (`INSERT`, `UPDATE`, `DELETE`, `MERGE`), `COPY INTO`, and user-managed tasks.
- It is **not** needed for: most DDL, `SHOW`/`DESCRIBE`, metadata-only queries, or serverless features (Snowpipe, Automatic Clustering, serverless tasks, and others).
- Warehouses are **independent**. Load on one does not affect another, even when both read the same table.
- Warehouse state is `STARTED`, `SUSPENDED`, or `RESIZING`. A suspended warehouse uses **no credits**.

## 2.2 Sizes and credits

Each size step **doubles** both compute and credits per hour.

| Size | Credits / hour | Credits / second |
|---|---|---|
| X-Small (XS) | 1 | 0.0003 |
| Small (S) | 2 | 0.0006 |
| Medium (M) | 4 | 0.0011 |
| Large (L) | 8 | 0.0022 |
| X-Large (XL) | 16 | 0.0044 |
| 2X-Large | 32 | 0.0089 |
| 3X-Large | 64 | 0.0178 |
| 4X-Large | 128 | 0.0356 |
| 5X-Large | 256 | 0.0711 |
| 6X-Large | 512 | 0.1422 |

### Billing rules

- Billing is **per second**, with a **60-second minimum** each time a warehouse **starts or resumes**.
- **Resizing up** bills the new size from the moment the extra compute is provisioned. A resize does not trigger a new 60-second minimum for the existing compute.
- A multi-cluster warehouse bills **each running cluster** separately.
- Doubling the size usually roughly halves the run time of a large, well-parallelized query, so the **total credits stay about the same** while the query finishes faster.

> **Exam trap:** Suspending and resuming a warehouse repeatedly within one minute charges the **60-second minimum each time**.

> **Exam trap:** Credits are charged for **warehouse uptime**, not per query. A warehouse that runs ten queries at once costs the same per second as one that runs a single query.

### Warehouse types

| Type | Use case | Notes |
|---|---|---|
| **Standard** | General SQL, BI, ELT | Default type. Snowflake also offers newer warehouse generations (for example Gen2) in some regions, so check current docs. |
| **Snowpark-optimized** | Memory-heavy workloads: ML training, large UDFs, Snowpark | About **16x memory per node** compared with standard. Higher credit rate. Historically required size Medium or larger, so check the current minimum. |

## 2.3 Key warehouse properties

| Property | Default | Meaning |
|---|---|---|
| `WAREHOUSE_SIZE` | `XSMALL` (SQL `CREATE`) | Compute size. Snowsight may suggest a different starting size. |
| `AUTO_SUSPEND` | `600` seconds (10 min) | Seconds of inactivity before suspending. `NULL` or `0` means never suspend (not recommended). |
| `AUTO_RESUME` | `TRUE` | Resume automatically when a query is submitted |
| `INITIALLY_SUSPENDED` | `FALSE` | Create the warehouse in a suspended state |
| `MIN_CLUSTER_COUNT` / `MAX_CLUSTER_COUNT` | 1 / 1 | Multi-cluster bounds [Enterprise+] |
| `SCALING_POLICY` | `STANDARD` | `STANDARD` or `ECONOMY` [Enterprise+] |
| `MAX_CONCURRENCY_LEVEL` | `8` | Target number of concurrent queries per cluster before queuing |
| `STATEMENT_TIMEOUT_IN_SECONDS` | `172800` (2 days) | Cancels long-running statements |
| `STATEMENT_QUEUED_TIMEOUT_IN_SECONDS` | `0` (no limit) | Cancels statements queued longer than this |
| `RESOURCE_MONITOR` | none | Credit quota control (see chapter 10) |
| `ENABLE_QUERY_ACCELERATION` | `FALSE` | Query Acceleration Service [Enterprise+] |
| `QUERY_ACCELERATION_MAX_SCALE_FACTOR` | `8` | Upper bound on acceleration compute, as a multiple of warehouse size |

```sql
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

ALTER WAREHOUSE ANALYTICS_WH SET WAREHOUSE_SIZE = 'LARGE';   -- scale up
ALTER WAREHOUSE ANALYTICS_WH SUSPEND;
ALTER WAREHOUSE ANALYTICS_WH RESUME;
```

> **Tip:** For BI or ad-hoc warehouses, an `AUTO_SUSPEND` of 60–300 seconds is typical. Very short values throw away the warehouse cache (section 2.6). For ELT warehouses that run back-to-back jobs, a longer value can be cheaper overall.

## 2.4 Scale up vs scale out

| | **Scale UP** (resize) | **Scale OUT** (multi-cluster) |
|---|---|---|
| What changes | Bigger warehouse: more compute per cluster | More clusters of the same size |
| Solves | **Complex or large queries**: slow execution, **spilling** to disk | **Concurrency**: many users or queries **queuing** |
| How | `ALTER WAREHOUSE ... SET WAREHOUSE_SIZE` (manual) | `MAX_CLUSTER_COUNT > 1`, then automatic |
| Edition | [Standard+] | [Enterprise+] |
| Effect on running queries | Running queries **finish on the old resources**; queued and new queries use the new size | New clusters take **new** queries; no single query gets faster |
| Automatic? | No. Snowflake never resizes a warehouse for you. | Yes, within MIN and MAX |

> **Exam trap:** A multi-cluster warehouse does **not** make an individual query faster. It reduces **queuing**. For a slow single query, scale **up**.

> **Exam trap:** Resizing a running warehouse does not interrupt or speed up queries that are **already executing**.

## 2.5 Multi-cluster warehouses [Enterprise+]

### Modes

| Mode | Configuration | Behavior |
|---|---|---|
| **Maximized** | `MIN_CLUSTER_COUNT = MAX_CLUSTER_COUNT` (both > 1) | All clusters start when the warehouse starts. Good for steady, high concurrency. |
| **Auto-scale** | `MIN_CLUSTER_COUNT < MAX_CLUSTER_COUNT` | Clusters start and stop with load, following the scaling policy |

The classic exam figure for `MAX_CLUSTER_COUNT` is **10**. Newer limits can be higher for some sizes, so check the docs.

### Scaling policies (auto-scale mode)

| Policy | Starts an extra cluster when… | Shuts a cluster down when… | Optimizes for |
|---|---|---|---|
| **Standard** (default) | A query is queued, or the system detects more queries than the running clusters can handle. Each successive cluster waits **20 seconds** after the previous one started. | After **2–3 consecutive checks** (1 minute apart) show the load could be handled by fewer clusters | **Performance**: minimal queuing |
| **Economy** | The system estimates there is enough queued work to keep a new cluster busy for at least **6 minutes** | After **5–6 consecutive checks** show the load could be redistributed | **Credits**: tolerates some queuing |

```sql
ALTER WAREHOUSE BI_WH SET
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 4
  SCALING_POLICY = 'ECONOMY';
```

> **Exam trap:** The scaling policy only matters in **auto-scale** mode. In maximized mode it has no effect.

> **Exam trap:** The worst-case credit cost of a multi-cluster warehouse is **size × MAX_CLUSTER_COUNT**. For example, a Medium with 4 clusters can use 16 credits per hour.

## 2.6 The four caching layers

Snowflake has three true caches, plus the remote storage layer they all shield you from. Many study guides count all four as "layers", so learn all four and know where each one lives.

| # | Layer | Lives in | What it holds | Lifetime | Needs a running warehouse? |
|---|---|---|---|---|---|
| 1 | **Metadata cache** | Cloud services | Micro-partition statistics: row counts, MIN/MAX, distinct counts, NULL counts, object metadata | Always maintained | **No**. `COUNT(*)`, `MIN`, `MAX` on a table can be answered from metadata. |
| 2 | **Query result cache** | Cloud services | The full result sets of queries run in the last 24 hours | **24 hours**, reset each time the result is reused, up to a maximum of **31 days** from the first run | **No** |
| 3 | **Warehouse (local disk) cache** | Memory and SSD of the warehouse's nodes | Raw micro-partition data read by earlier queries | Until the warehouse is **suspended** (or resized down) | Yes |
| 4 | **Remote disk** (storage layer) | Cloud object storage | All persisted micro-partitions | Persistent | Yes, to read it |

### Rules for result cache reuse

A query reuses a cached result only if **all** of these hold:

1. The new query text is **syntactically identical** to the earlier one. Case and whitespace differences prevent reuse in general; aliases and comments count.
2. The **underlying table data has not changed**. Any DML, or reclustering that changes micro-partitions, invalidates the result.
3. The query contains **no non-deterministic or runtime functions** such as `CURRENT_TIMESTAMP()`, `RANDOM()`, or `UUID_STRING()`. (`CURRENT_DATE()` is allowed.)
4. It contains no **external functions** and no UDFs that prevent reuse.
5. The role has the **privileges** needed on all objects in the query.
6. `USE_CACHED_RESULT = TRUE`, which is the default. It can be set at account, user, or session level.
7. The persisted result is still available (it has not been purged), and no configuration option that affects the result has changed.

```sql
ALTER SESSION SET USE_CACHED_RESULT = FALSE;  -- benchmark honestly
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));  -- post-process a cached result
```

> **Exam trap:** The result cache is **not tied to a warehouse or to a user**. Any user whose role has the needed privileges can reuse a result, even when using a different warehouse, or with the warehouse suspended.

> **Exam trap:** Suspending a warehouse **drops the warehouse cache**, but the **result cache survives** because it lives in cloud services.

> **Exam trap:** The **Query Profile** shows `QUERY RESULT REUSE` when the result cache was used, and **"Percentage scanned from cache"** for the warehouse cache. Do not mix them up.

### Choosing auto-suspend with cache in mind

| Workload | Suggested auto-suspend | Why |
|---|---|---|
| Ad-hoc / BI dashboards | 5–10 min | Keeps the warehouse cache warm between related queries |
| Scheduled ELT | 60 s or immediate | Little reuse between jobs, so idle time is wasted credits |
| Data loading | 60 s | Loads read files from stages, so the cache gives little benefit |

## 2.7 Concurrency and queuing

- Each cluster runs queries concurrently. `MAX_CONCURRENCY_LEVEL` (default **8**) is the target number of concurrent statements. Heavier queries can lower the effective concurrency.
- Queries that do not fit are **queued**. Queuing shows up as `QUEUED_OVERLOAD_TIME` in query history, and as a queued bar in the Snowsight warehouse load chart.
- Ways to fix queuing, in order: use **multi-cluster** [Enterprise+]; split workloads onto **separate warehouses**; or make queries cheaper.

## Self-check

**1. A single complex query spills to remote storage. Should you scale up or out?**
<details><summary>Answer</summary><b>Scale up</b> to a larger warehouse, which has more memory and local disk. Scaling out only helps with concurrency and queuing.</details>

**2. How many credits per hour does a Large multi-cluster warehouse use at most, with MAX_CLUSTER_COUNT = 3?**
<details><summary>Answer</summary>8 × 3 = <b>24 credits per hour</b>.</details>

**3. What is the minimum billing increment when a warehouse resumes?**
<details><summary>Answer</summary><b>60 seconds</b>. After that, billing is per second.</details>

**4. Which scaling policy waits until there is about 6 minutes of work before starting a new cluster?**
<details><summary>Answer</summary><b>Economy</b>.</details>

**5. How long does the query result cache keep a result?**
<details><summary>Answer</summary><b>24 hours</b>. Each reuse resets the clock, up to a maximum of <b>31 days</b> from the original run.</details>

**6. A user runs the same query again after the warehouse has auto-suspended, and gets results instantly. Which cache served it?**
<details><summary>Answer</summary>The <b>query result cache</b> in cloud services. The warehouse cache was lost when the warehouse suspended.</details>
