# 12 — Governance and Monitoring

**Exam domains:** 2 (Security), 3 (Performance), and 1 (Architecture)

## 12.1 ACCOUNT_USAGE vs INFORMATION_SCHEMA

| | **SNOWFLAKE.ACCOUNT_USAGE** | **&lt;db&gt;.INFORMATION_SCHEMA** |
|---|---|---|
| Where | The shared `SNOWFLAKE` database (provided by Snowflake) | Every database has its own |
| Scope | **Whole account** | That database's objects, plus some account-level table functions |
| **Dropped objects** | **Included** (with `DELETED` timestamps) | **Not included** |
| **Latency** | **45 minutes to 3 hours**, depending on the view | **None** (real time) |
| **Retention** | **365 days** (1 year) | **7 days to 6 months**, depending on the view or function (often 7 or 14 days) |
| Access | `ACCOUNTADMIN` by default. Others need `IMPORTED PRIVILEGES` on the SNOWFLAKE database, or SNOWFLAKE **database roles** (`OBJECT_VIEWER`, `USAGE_VIEWER`, `GOVERNANCE_VIEWER`, `SECURITY_VIEWER`). | Any role; results are **filtered to objects the role can access** |
| Form | Views | Views **and table functions** (`TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())`) |

Related schemas in the SNOWFLAKE database:

| Schema | Content |
|---|---|
| `ACCOUNT_USAGE` | Account metadata and usage history |
| `READER_ACCOUNT_USAGE` | Usage for reader accounts the provider created |
| `ORGANIZATION_USAGE` | Organization-wide usage and billing (ORGADMIN or granted roles) |
| `DATA_SHARING_USAGE` | Listing and consumer telemetry for providers |
| `CORE`, `ALERT`, `ML`, `CORTEX`, ... | Built-in functions and classes (varies by release) |

> **Exam trap:** For **real-time** information, or the **last few minutes**, use INFORMATION_SCHEMA. For **history beyond 7–14 days**, or **dropped objects**, use ACCOUNT_USAGE.

### Frequently tested views and functions

| Need | ACCOUNT_USAGE (365 days) | INFORMATION_SCHEMA |
|---|---|---|
| Queries | `QUERY_HISTORY` (about 45 min latency) | `QUERY_HISTORY()`, `QUERY_HISTORY_BY_USER()`, `..._BY_WAREHOUSE()`, `..._BY_SESSION()` (**7 days**) |
| Logins | `LOGIN_HISTORY` (up to 2 h) | `LOGIN_HISTORY()` (7 days) |
| Warehouse credits | `WAREHOUSE_METERING_HISTORY` (up to 3 h) | `WAREHOUSE_METERING_HISTORY()` (6 months) |
| Warehouse load | `WAREHOUSE_LOAD_HISTORY` | `WAREHOUSE_LOAD_HISTORY()` (14 days) |
| File loads | `COPY_HISTORY` (up to 2 h), `LOAD_HISTORY` (bulk only, up to 90 min) | `COPY_HISTORY()` (14 days), `LOAD_HISTORY` view (14 days) |
| Snowpipe credits | `PIPE_USAGE_HISTORY` | `PIPE_USAGE_HISTORY()` (14 days) |
| Clustering credits | `AUTOMATIC_CLUSTERING_HISTORY` | `AUTOMATIC_CLUSTERING_HISTORY()` (14 days) |
| Storage | `STORAGE_USAGE`, `DATABASE_STORAGE_USAGE_HISTORY`, `STAGE_STORAGE_USAGE_HISTORY`, `TABLE_STORAGE_METRICS` | `TABLE_STORAGE_METRICS` view, `DATABASE_STORAGE_USAGE_HISTORY()` |
| Tasks | `TASK_HISTORY` | `TASK_HISTORY()` (7 days) |
| Grants | `GRANTS_TO_ROLES`, `GRANTS_TO_USERS` | `TABLE_PRIVILEGES`, `OBJECT_PRIVILEGES` |
| Users and roles | `USERS`, `ROLES` | (account objects aren't here) |
| Object dependencies | `OBJECT_DEPENDENCIES` | |
| Policies and tags | `POLICY_REFERENCES`, `TAG_REFERENCES` | `POLICY_REFERENCES()`, `TAG_REFERENCES()`, `TAG_REFERENCES_ALL_COLUMNS()` |
| Column-level access | **`ACCESS_HISTORY`** [Enterprise+] (up to 3 h) | |
| Total metering | `METERING_HISTORY`, `METERING_DAILY_HISTORY` | |

```sql
SELECT warehouse_name, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1 ORDER BY 2 DESC;

SELECT query_id, query_text, total_elapsed_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_WAREHOUSE(WAREHOUSE_NAME => 'BI_WH', RESULT_LIMIT => 100));
```

## 12.2 Object tagging [Enterprise+]

A **tag** is a schema-level object that holds a string value you assign to objects: warehouses, databases, tables, columns, users, roles, and more.

```sql
CREATE TAG governance.tags.cost_center ALLOWED_VALUES 'finance', 'marketing';
CREATE TAG governance.tags.pii;
ALTER WAREHOUSE bi_wh SET TAG governance.tags.cost_center = 'finance';
ALTER TABLE customers MODIFY COLUMN email SET TAG governance.tags.pii = 'email';

SELECT SYSTEM$GET_TAG('governance.tags.pii', 'customers.email', 'COLUMN');
SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('customers', 'TABLE'));
```

| Fact | Value |
|---|---|
| Max tags per object | **50** (combined across the object and its columns) |
| Tag value | A string, up to **256 characters** |
| `ALLOWED_VALUES` | Restricts the accepted values |
| **Tag lineage (inheritance)** | A tag on a database, schema, or table is **inherited** by child objects and columns, unless a child sets its own value |
| Tag propagation | Newer: tags can propagate automatically to derived objects (check the docs) |
| **Tag-based masking** | `ALTER TAG pii SET MASKING POLICY mask_string;` masks every column with that tag whose data type matches the policy |
| Uses | Cost attribution, PII tracking, policy automation |

## 12.3 Data classification [Enterprise+]

- Analyzes column contents and suggests **semantic categories** (for example EMAIL, NAME, PHONE_NUMBER) and **privacy categories** (**IDENTIFIER**, **QUASI_IDENTIFIER**, **SENSITIVE**).
- Run it with `SYSTEM$CLASSIFY('db.schema.table', {'auto_tag': true})`, or set up **automatic classification** with classification profiles.
- Results can apply the system tags `SNOWFLAKE.CORE.SEMANTIC_CATEGORY` and `SNOWFLAKE.CORE.PRIVACY_CATEGORY`.

## 12.4 Lineage and access history

| Feature | What it provides | Edition |
|---|---|---|
| **`ACCESS_HISTORY`** | For each query: `direct_objects_accessed`, `base_objects_accessed`, `objects_modified` (with **column-level lineage**), and the policies that applied | **[Enterprise+]** |
| **`OBJECT_DEPENDENCIES`** | Which objects depend on which (for example view → table) | [Standard+] |
| **Snowsight lineage graph** | Visual upstream and downstream lineage for tables, views, and columns | Check the docs (newer feature) |
| **Data metric functions** (data quality) | System DMFs (`NULL_COUNT`, `DUPLICATE_COUNT`, `FRESHNESS`, `ROW_COUNT`) and custom ones, run on a schedule | [Enterprise+] |
| **Trust Center** | Security posture scanners (CIS benchmarks, MFA readiness) | [Standard+] |

> **Exam trap:** "Which users read column X last month?" is answered by `ACCESS_HISTORY`, which needs [Enterprise+]. `QUERY_HISTORY` alone doesn't resolve columns or base objects behind views.

## 12.5 Parameters

Parameters control behavior. They're set at different levels, and a **lower level overrides a higher level**.

```
ACCOUNT ─┬─▶ USER ─▶ SESSION              (session parameters)
         ├─▶ WAREHOUSE                     (warehouse/object parameters)
         └─▶ DATABASE ─▶ SCHEMA ─▶ TABLE   (object parameters)
```

| Type | Examples | Set with |
|---|---|---|
| **Account** parameters (account level only) | `MIN_DATA_RETENTION_TIME_IN_DAYS`, `PERIODIC_DATA_REKEYING`, `NETWORK_POLICY`, `SAML_IDENTITY_PROVIDER`, `REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION`, `PREVENT_UNLOAD_TO_INLINE_URL` | `ALTER ACCOUNT SET ...` (ACCOUNTADMIN) |
| **Session** parameters (account → user → session) | `TIMEZONE` (default America/Los_Angeles), `QUERY_TAG`, `USE_CACHED_RESULT`, `AUTOCOMMIT`, `DATE_OUTPUT_FORMAT`, `STATEMENT_TIMEOUT_IN_SECONDS`, `TIMESTAMP_TYPE_MAPPING`, `LOCK_TIMEOUT` | `ALTER SESSION SET ...`, `ALTER USER ... SET ...` |
| **Object** parameters | `DATA_RETENTION_TIME_IN_DAYS`, `MAX_DATA_EXTENSION_TIME_IN_DAYS`, `STATEMENT_TIMEOUT_IN_SECONDS` (warehouse), `MAX_CONCURRENCY_LEVEL`, `DEFAULT_DDL_COLLATION` | `ALTER <object> SET ...` |

```sql
SHOW PARAMETERS IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT%' IN WAREHOUSE bi_wh;
SHOW PARAMETERS IN TABLE orders;
ALTER SESSION SET QUERY_TAG = 'nightly_etl';
ALTER SESSION UNSET QUERY_TAG;
```

> **Exam trap:** `STATEMENT_TIMEOUT_IN_SECONDS` can be set on **both** the session or user **and** the warehouse. When both are set, the **lower (shorter) value applies**.

> **Exam trap:** `SHOW PARAMETERS` output includes a `level` column (for example `SESSION`, `ACCOUNT`, or blank for the default), which tells you where the effective value came from.

## 12.6 Monitoring in Snowsight

| Area | Use |
|---|---|
| **Query History** | Filter by user, warehouse, status; open the Query Profile |
| **Warehouse Activity / load chart** | Running vs **queued** load over time |
| **Cost Management** | Credits by warehouse and service type, budgets, resource monitors |
| **Copy History / Pipe** | Load status per file |
| **Task runs / Dynamic table graphs** | Pipeline health |
| **Governance & Security dashboards** | Tag and policy coverage, Trust Center |

## Self-check

**1. What are the typical latency and retention of ACCOUNT_USAGE views?**
<details><summary>Answer</summary>Latency of <b>45 minutes to 3 hours</b>, and retention of <b>365 days</b>.</details>

**2. Which source shows dropped tables: ACCOUNT_USAGE or INFORMATION_SCHEMA?**
<details><summary>Answer</summary><b>ACCOUNT_USAGE</b>.</details>

**3. How long does `INFORMATION_SCHEMA.QUERY_HISTORY()` look back?**
<details><summary>Answer</summary><b>7 days</b>.</details>

**4. What's the maximum number of tags on a single object?**
<details><summary>Answer</summary><b>50</b>.</details>

**5. How does a non-ACCOUNTADMIN role get access to SNOWFLAKE.ACCOUNT_USAGE?**
<details><summary>Answer</summary>Grant <code>IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE</code>, or grant a SNOWFLAKE database role such as <code>SNOWFLAKE.USAGE_VIEWER</code>.</details>

**6. Session and warehouse STATEMENT_TIMEOUT_IN_SECONDS are both set. Which applies?**
<details><summary>Answer</summary>The <b>lower</b> of the two values.</details>
