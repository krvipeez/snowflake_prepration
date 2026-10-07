# 11 — Pipelines and Programmability

**Exam domain:** 5 (Data Transformations, 20%). The topics also show up in domain 1.

## 11.1 Streams [Standard+]

A **stream** records **change data capture (CDC)** for a source object. It stores an **offset**, a point in the table's version history, **not a copy of the data**. Querying a stream returns the net changes between the offset and now.

```sql
CREATE STREAM orders_stream ON TABLE orders;                       -- standard (delta)
CREATE STREAM orders_ins    ON TABLE orders APPEND_ONLY = TRUE;    -- inserts only
CREATE STREAM ext_stream    ON EXTERNAL TABLE ext_orders INSERT_ONLY = TRUE;
CREATE STREAM s_at          ON TABLE orders AT(OFFSET => -3600);   -- start from the past (Time Travel)
SHOW STREAMS;   -- STALE, STALE_AFTER, MODE columns
SELECT SYSTEM$STREAM_HAS_DATA('ORDERS_STREAM');
```

### Stream types

| Type | Captures | Supported sources |
|---|---|---|
| **Standard** (delta) | Inserts, updates, deletes (net changes) | Tables, views (including secure views), dynamic tables, Iceberg tables, directory tables, event tables |
| **Append-only** | **Inserts only**; ignores updates and deletes. Cheaper. | Tables, views, dynamic tables, Iceberg tables |
| **Insert-only** | Inserts only | **External tables**, externally managed Iceberg tables |

### Metadata columns

| Column | Values |
|---|---|
| `METADATA$ACTION` | `INSERT` or `DELETE` |
| `METADATA$ISUPDATE` | `TRUE` if the row is part of an UPDATE |
| `METADATA$ROW_ID` | Unique, immutable row ID used to track changes |

An **UPDATE** appears as **two rows**: a `DELETE` (old values) and an `INSERT` (new values), both with `METADATA$ISUPDATE = TRUE`.

### Offsets, consumption, and staleness

- The offset **advances only when the stream is consumed in a DML statement that commits**, such as `INSERT INTO ... SELECT FROM stream` or `MERGE ... USING stream`.
- A plain `SELECT` from the stream does **not** advance it.
- Within an explicit transaction, the stream returns the same changes to every statement (**repeatable read**). It advances when the transaction commits.
- A stream becomes **stale** if its offset falls outside the source's data retention. To prevent this, Snowflake temporarily extends retention up to `MAX_DATA_EXTENSION_TIME_IN_DAYS` (default **14 days**) for tables whose retention is shorter. A stale stream must be **recreated**.
- Creating the first stream on a table enables **change tracking**, which adds hidden columns.
- `CHANGES` clause: `SELECT * FROM t CHANGES(INFORMATION => DEFAULT) AT(...)` reads change data **without creating a stream**. It needs change tracking enabled.

> **Exam trap:** Reading a stream with `SELECT` **does not consume it**. Only a committed DML statement that reads the stream does.

> **Exam trap:** Several consumers each need **their own stream**. One stream's offset is shared by everyone who reads it.

## 11.2 Tasks [Standard+]

A **task** runs a single SQL statement, a stored procedure call, or a Snowflake Scripting block, **on a schedule** or **after other tasks**.

```sql
CREATE TASK t_load_orders
  WAREHOUSE = etl_wh                      -- omit for serverless
  SCHEDULE = 'USING CRON 0 */2 * * * UTC' -- or SCHEDULE = '15 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('ORDERS_STREAM')
AS
  INSERT INTO orders_hist SELECT * FROM orders_stream;

CREATE TASK t_child AFTER t_load_orders AS CALL sp_refresh_marts();

ALTER TASK t_child RESUME;        -- resume children first
ALTER TASK t_load_orders RESUME;  -- then the root
EXECUTE TASK t_load_orders;       -- run once now (manual)
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) ORDER BY scheduled_time DESC;
```

| Topic | Detail |
|---|---|
| Initial state | **Created suspended**; you must `ALTER TASK ... RESUME` |
| Compute | **User-managed** (`WAREHOUSE = ...`) or **serverless** (omit WAREHOUSE; size with `USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE`; Snowflake right-sizes it over time) |
| Privileges | The task owner needs **`EXECUTE TASK`** (account-level, which ACCOUNTADMIN grants). Serverless tasks also need **`EXECUTE MANAGED TASK`**. |
| Schedules | `n MINUTE`, or `USING CRON <expr> <time zone>`. Only the **root** task has a schedule; children use `AFTER`. |
| Task graphs (DAGs) | One root; up to **1,000 tasks** per graph; a task can have up to **100 predecessors** and **100 children**. A **finalizer** task runs once the graph completes. |
| WHEN condition | Evaluated in cloud services. If FALSE, the run is skipped and **no warehouse starts**. Typically `SYSTEM$STREAM_HAS_DATA`. |
| Overlap | `ALLOW_OVERLAPPING_EXECUTION = FALSE` by default: a new run is skipped while the previous one is still running |
| Failures | `SUSPEND_TASK_AFTER_NUM_FAILURES` (default 10) auto-suspends a task after repeated failures |
| Modifying a graph | **Suspend the root task** before changing child tasks |
| History | `INFORMATION_SCHEMA.TASK_HISTORY()` (7 days); `ACCOUNT_USAGE.TASK_HISTORY` (365 days) |
| Triggered tasks | Newer: run when a stream has data, with no schedule |

> **Exam trap:** A new task does **nothing** until it's resumed, and the owner role needs `EXECUTE TASK`. SYSADMIN doesn't have it by default.

> **Exam trap:** Only the **root** task in a graph has a `SCHEDULE`. Children are defined with `AFTER`.

> **Exam trap:** **Serverless** tasks are billed as serverless compute, and **resource monitors don't control them**.

## 11.3 Dynamic tables [Standard+]

A **dynamic table** is a table defined by a query. Snowflake **refreshes it automatically** so that its data is no older than the **target lag**.

```sql
CREATE DYNAMIC TABLE dt_customer_revenue
  TARGET_LAG = '15 minutes'          -- or TARGET_LAG = DOWNSTREAM
  WAREHOUSE = transform_wh
  REFRESH_MODE = AUTO                -- AUTO | INCREMENTAL | FULL
AS
SELECT customer_id, COUNT(*) AS orders, SUM(amount) AS revenue
FROM orders GROUP BY customer_id;

ALTER DYNAMIC TABLE dt_customer_revenue REFRESH;    -- manual refresh
ALTER DYNAMIC TABLE dt_customer_revenue SUSPEND;
SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY());
```

- `TARGET_LAG = DOWNSTREAM` means "refresh only when a downstream dynamic table needs it".
- The minimum target lag is **1 minute** (classic figure).
- You **can't** run DML against a dynamic table. Its content is defined by its query.
- Dynamic tables can be chained to build declarative pipelines. Snowsight shows the DAG.
- Refreshes use **your warehouse**, so resource monitors apply to that warehouse.

### Choosing between pipeline options

| | **Streams + tasks** | **Dynamic tables** | **Materialized views** |
|---|---|---|---|
| Style | Imperative (you write the MERGE logic) | **Declarative** (just the SELECT) | Declarative |
| Freshness | Your schedule | **Target lag** | Always current at query time |
| Joins / complex SQL | Anything | Joins, aggregations, window functions, UNION, and more | **Single table**, limited functions |
| Compute | Warehouse or serverless tasks | Your warehouse | Serverless |
| Procedural logic, external calls, SCD Type 2 control | **Yes** | Limited | No |
| Edition | [Standard+] | [Standard+] | **[Enterprise+]** |
| Best for | Fine-grained control, custom CDC | Most transformation pipelines | Speeding up repeated queries on one table |

## 11.4 User-defined functions (UDFs) [Standard+]

| Kind | Returns | Languages |
|---|---|---|
| **Scalar UDF** | One value per input row | SQL, JavaScript, Python, Java, Scala |
| **UDTF** (table function) | A set of rows: `RETURNS TABLE(...)`, called with `TABLE(...)` | SQL, JavaScript, Python, Java, Scala |
| **UDAF** (aggregate) | One value per group | Python |
| **Vectorized Python UDF / UDTF** | Processes pandas batches | Python |
| **External function** | Calls a remote service (for example AWS API Gateway + Lambda) through an **API integration** | Any (remote) |

```sql
CREATE FUNCTION f_tax(amount NUMBER(10,2)) RETURNS NUMBER(10,2) AS 'amount * 0.18';

CREATE FUNCTION f_initials(name STRING) RETURNS STRING
  LANGUAGE PYTHON RUNTIME_VERSION = '3.11' HANDLER = 'run' AS
$$
def run(name):
    return ''.join(p[0] for p in name.split() if p)
$$;

CREATE FUNCTION f_double(x FLOAT) RETURNS FLOAT LANGUAGE JAVASCRIPT AS 'return X * 2;';  -- args are UPPERCASE in JS

CREATE SECURE FUNCTION f_secret(...) ...;   -- definition hidden, shareable
```

- UDFs can be **overloaded**: same name, different argument signatures.
- Python UDFs can use Anaconda packages through `PACKAGES = (...)`. This may require the organization to accept the Anaconda terms.
- **External access integrations** let Python and Java code call external endpoints securely, using network rules and secrets.

> **Exam trap:** In **JavaScript** UDFs and procedures, argument names must be referenced in **UPPERCASE**.

## 11.5 Stored procedures [Standard+]

```sql
CREATE OR REPLACE PROCEDURE sp_purge_old(days NUMBER)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER                    -- default; or EXECUTE AS CALLER
AS
$$
DECLARE n NUMBER;
BEGIN
  DELETE FROM events WHERE event_ts < DATEADD(day, -1 * :days, CURRENT_TIMESTAMP());
  n := SQLROWCOUNT;
  RETURN 'Deleted ' || n;
END;
$$;
CALL sp_purge_old(30);
```

- Languages: **SQL (Snowflake Scripting)**, JavaScript, Python, Java, Scala.
- **Owner's rights** (the default) runs with the owner's privileges, and restricts some session operations. **Caller's rights** runs with the caller's privileges and session context.
- Procedures can run **DDL and DML** and control transactions.
- Called with `CALL`; they **can't** be used inside a SELECT.

### UDF vs stored procedure

| | UDF | Stored procedure |
|---|---|---|
| Invoked by | Inside SQL: `SELECT f(x)` | `CALL p()` |
| Returns | A value (scalar) or rows (UDTF), per row | A single value or a table; optional |
| DDL / DML inside | **No** (it computes values) | **Yes** |
| Typical use | Calculations, parsing, enrichment | Admin tasks, ETL orchestration, dynamic SQL |
| Security context | Owner (definition) | Owner's rights (default) or caller's rights |

> **Exam trap:** If a question needs a routine that **creates tables or runs DML**, the answer is a **stored procedure**, not a UDF.

## 11.6 Snowflake Scripting essentials

- Anonymous blocks: `EXECUTE IMMEDIATE $$ DECLARE ... BEGIN ... END; $$;`
- Variables (`LET x := 1;`), `IF`, `CASE`, `FOR`, `WHILE`, `LOOP`, `CURSOR`, `RESULTSET`, and `EXCEPTION` handlers.
- `SQLROWCOUNT`, `SQLFOUND`, `SQLNOTFOUND` hold the result of the last DML statement.
- Inside SQL statements, reference variables and arguments with a **colon prefix**: `:days`.

## 11.7 Snowpark [Standard+]

- A **DataFrame API** for **Python, Java, Scala**. Operations are **lazy**: they build a plan that runs **inside Snowflake** when an action happens (`collect()`, `show()`, `write.save_as_table()`).
- No data leaves Snowflake. Processing is pushed down to warehouses.
- Use it to write UDFs, UDTFs, and stored procedures in those languages; it's also used for ML (Snowpark ML / Snowflake ML).
- **Snowpark-optimized warehouses** give memory-heavy workloads about 16x memory per node.

```python
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as sum_
session = Session.builder.configs(conn_params).create()
df = (session.table("ORDERS")
        .filter(col("STATUS") == "DELIVERED")
        .group_by("CUSTOMER_ID")
        .agg(sum_("AMOUNT").alias("REVENUE")))
df.write.save_as_table("CUSTOMER_REVENUE", mode="overwrite")   # executes in Snowflake
```

## 11.8 Other programmability features

| Feature | Summary | Edition |
|---|---|---|
| **Sequences** | `CREATE SEQUENCE s START = 1 INCREMENT = 1`; `s.NEXTVAL`; may have gaps | [Standard+] |
| **Alerts** | `CREATE ALERT ... SCHEDULE ... IF (EXISTS (SELECT ...)) THEN <action>` | [Standard+] |
| **Notification integrations** | Email, webhooks, cloud queues; `SYSTEM$SEND_EMAIL` | [Standard+] |
| **Transactions** | `AUTOCOMMIT` defaults to TRUE; `BEGIN` ... `COMMIT`/`ROLLBACK`; **DDL commits implicitly**; isolation is **READ COMMITTED**; `LOCK_TIMEOUT` defaults to 43,200 s (12 h) | [Standard+] |
| **Streamlit in Snowflake / Notebooks** | Apps and notebooks running inside Snowflake | [Standard+] |

## Self-check

**1. What two rows does an UPDATE produce in a standard stream?**
<details><summary>Answer</summary>A <b>DELETE</b> row (old values) and an <b>INSERT</b> row (new values), both with <code>METADATA$ISUPDATE = TRUE</code>.</details>

**2. Does `SELECT * FROM my_stream` advance the offset?**
<details><summary>Answer</summary>No. Only a committed DML statement that reads from the stream does.</details>

**3. What state is a task in right after `CREATE TASK`?**
<details><summary>Answer</summary><b>Suspended</b>. Resume it with <code>ALTER TASK ... RESUME</code>, which needs the EXECUTE TASK privilege.</details>

**4. Which privilege does a serverless task need beyond EXECUTE TASK?**
<details><summary>Answer</summary><b>EXECUTE MANAGED TASK</b>.</details>

**5. What does TARGET_LAG control on a dynamic table?**
<details><summary>Answer</summary>The maximum allowed staleness of the table's data compared with its sources. Snowflake schedules refreshes to stay within it.</details>

**6. You need a routine that creates a table and loads it. UDF or procedure?**
<details><summary>Answer</summary>A <b>stored procedure</b>. UDFs can't run DDL or DML.</details>
