# 08 — Data Protection

**Exam domain:** 6 (Data Protection and Data Sharing, 10%)

## 8.1 Continuous Data Protection lifecycle

```
  Current data ──(change/drop)──▶ TIME TRAVEL ──(retention ends)──▶ FAIL-SAFE ──(7 days)──▶ purged
                                 user-accessible                     Snowflake Support only
                                 0–1 day (Standard)                  7 days, permanent tables
                                 0–90 days (Enterprise+)             0 days, transient/temporary
```

## 8.2 Time Travel [Standard+] (extended retention [Enterprise+])

Time Travel lets you **query, clone, and restore** data as it existed at an earlier point within the retention period.

### Retention by table type and edition

| Object type | Standard | Enterprise+ |
|---|---|---|
| Permanent table, schema, database | 0 or **1** day (default 1) | **0–90** days (default 1) |
| Transient table, schema, database | 0 or 1 day | 0 or 1 day |
| Temporary table | 0 or 1 day (and never beyond the session) | 0 or 1 day |

### Parameters

| Parameter | Level | Meaning |
|---|---|---|
| `DATA_RETENTION_TIME_IN_DAYS` | Account, database, schema, table | Time Travel retention. Default **1**. `0` disables Time Travel for the object. |
| `MIN_DATA_RETENTION_TIME_IN_DAYS` | **Account only** (ACCOUNTADMIN) | Floor for effective retention: effective = MAX(DATA_RETENTION, MIN_DATA_RETENTION) |
| `MAX_DATA_EXTENSION_TIME_IN_DAYS` | Account, database, schema, table | How far Snowflake may extend retention to stop **streams** going stale. Default **14**. |

### Using Time Travel

```sql
-- query the past
SELECT * FROM orders AT(TIMESTAMP => '2026-10-07 09:00:00'::TIMESTAMP_LTZ);
SELECT * FROM orders AT(OFFSET => -60*30);                     -- 30 minutes ago (seconds)
SELECT * FROM orders BEFORE(STATEMENT => '01b2c3d4-...');      -- just before a query ran

-- restore via clone
CREATE TABLE orders_restored CLONE orders BEFORE(STATEMENT => '01b2c3d4-...');

-- undrop
DROP TABLE orders;
UNDROP TABLE orders;
SHOW TABLES HISTORY LIKE 'ORDERS';      -- dropped versions show DROPPED_ON
UNDROP SCHEMA s;  UNDROP DATABASE d;
```

| Clause | Point in time |
|---|---|
| `AT(TIMESTAMP => ts)` | Exactly at `ts`, **including** changes made at that moment |
| `AT(OFFSET => -n)` | `n` **seconds** before now |
| `AT(STATEMENT => qid)` | Including the changes made by the statement |
| `BEFORE(STATEMENT => qid)` | Immediately **before** the statement ran |

> **Exam trap:** `OFFSET` is in **seconds**, not minutes.

> **Exam trap:** `UNDROP` fails if an object with **the same name already exists**. Rename the current object first, then run `UNDROP`.

> **Exam trap:** Requesting a time **outside the retention period**, or **before the object existed**, returns an error.

### Changing retention

- **Increasing** retention affects data that is currently in Time Travel: it stays longer.
- **Decreasing** retention moves data older than the new period into **Fail-safe** (for permanent tables) once the background process runs.
- Retention set on a **database or schema** is inherited by child objects that don't set it explicitly.

> **Exam trap:** When a **database or schema is dropped**, child objects that had their **own explicit retention** don't keep it. The **parent's retention** applies to the whole dropped container. To keep a child's longer retention, drop the child separately first.

> **Exam trap:** Setting `DATA_RETENTION_TIME_IN_DAYS = 0` on a permanent table turns off Time Travel for it, but **Fail-safe still applies** (7 days).

## 8.3 Fail-safe [Standard+]

| Property | Value |
|---|---|
| Duration | **7 days**, fixed. It can't be configured or disabled for permanent tables. |
| Starts | When Time Travel retention ends |
| Applies to | **Permanent** tables only. Transient and temporary tables have **0 days**. |
| Who can recover | **Snowflake Support only**, best-effort; it can take hours to days |
| Purpose | Disaster recovery of historical data. It is **not** a backup you can query. |
| Cost | Fail-safe storage is billed (`FAILSAFE_BYTES` in `TABLE_STORAGE_METRICS`) |

> **Exam trap:** Fail-safe data **can't be queried or cloned** by users. If a question mentions recovery "using SQL", the answer is Time Travel, not Fail-safe.

> **Exam trap:** The maximum total recovery window for a permanent table in Enterprise is **90 + 7 = 97 days**. In Standard it's **1 + 7 = 8 days**.

## 8.4 Zero-copy cloning [Standard+]

`CREATE <object> <name> CLONE <source>` creates a copy **without copying data**. The clone references the **same micro-partitions** through metadata. Storage is only charged for micro-partitions that change after the clone diverges.

```sql
CREATE DATABASE dev_db CLONE prod_db;
CREATE SCHEMA analytics_bak CLONE analytics AT(OFFSET => -3600);
CREATE TABLE orders_test CLONE orders;
CREATE TRANSIENT TABLE orders_scratch CLONE orders;   -- permanent → transient is allowed
```

### What can be cloned

| Can be cloned | Notes |
|---|---|
| Databases, schemas, tables (permanent, transient, temporary, dynamic) | Cloning a container recursively clones its children |
| Streams | The clone's stream **starts fresh**: unconsumed changes from the source aren't available in the clone |
| Tasks (within a cloned db/schema) | Cloned tasks are **suspended** and must be resumed |
| Pipes (within a cloned db/schema) | Only pipes that reference **external** stages are cloned. Cloned pipes are **paused**. |
| Stages | **External** named stages are cloned. **Internal named stages aren't** (classic rule; check the docs). |
| File formats, sequences | Sequences keep their current value |
| Alerts, policies, tags (within cloned containers) | |

| **Cannot** be cloned | |
|---|---|
| Warehouses, users, roles, resource monitors, integrations, shares | Account-level, non-data objects |
| Shared databases (from a provider) | The consumer can't clone a share |
| Internal named stages (classic rule) | Files in internal stages are not copied |

### Cloning rules to remember

- **Privileges:** the clone does **not** copy the privileges granted on the **source object itself**. When you clone a database or schema, **child objects keep** their grants. `CREATE TABLE ... CLONE ... COPY GRANTS` copies the table's grants.
- **Load metadata** isn't copied, so files already loaded into the source can be loaded again into the clone.
- **Time Travel data** of the source isn't part of the clone's history: the clone's Time Travel starts at creation.
- You **can** clone permanent → transient or temporary. You **can't** clone transient or temporary → permanent.
- Cloning large containers is a **metadata operation** that uses cloud services, and runs without a warehouse.
- **DML running during a clone** isn't included if it commits after the clone's snapshot time. Use `AT` or `BEFORE` for a precise point in time.

> **Exam trap:** A cloned table **uses no extra storage at first**. Storage grows only as either the clone or the source is modified.

> **Exam trap:** `RETAINED_FOR_CLONE_BYTES` in `TABLE_STORAGE_METRICS` counts micro-partitions that the source deleted but a clone still references. They're still billed.

## 8.5 Replication and failover

### Concepts

| Term | Meaning | Edition |
|---|---|---|
| **Primary database** | The writable source | [Standard+] |
| **Secondary database** | **Read-only** replica in another account, in the same or a different region or cloud | [Standard+] |
| **Database replication** | Copies database objects and data, refreshed with `ALTER DATABASE ... REFRESH` or on a group schedule | [Standard+] |
| **Replication group** | A set of objects (databases, shares, and in BC+ account objects) replicated together, consistently, on a schedule | [Standard+] for databases and shares |
| **Account object replication** | Users, roles, grants, warehouses, resource monitors, network policies, integrations, parameters | **[Business Critical+]** |
| **Failover group** | A replication group that can be **promoted** to primary in the target account | **[Business Critical+]** |
| **Client Redirect** | A **connection** object (URL) that can be pointed at the account currently acting as primary, so clients reconnect transparently | **[Business Critical+]** |

```sql
-- source account (ORGADMIN must enable replication for accounts in the org)
CREATE FAILOVER GROUP fg_prod
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES
  ALLOWED_DATABASES = prod_db
  ALLOWED_ACCOUNTS = myorg.dr_account
  REPLICATION_SCHEDULE = '10 MINUTE';

-- target account
CREATE FAILOVER GROUP fg_prod AS REPLICA OF myorg.prod_account.fg_prod;
ALTER FAILOVER GROUP fg_prod REFRESH;
ALTER FAILOVER GROUP fg_prod PRIMARY;      -- failover: promote target
```

### Replication facts

- Replication **requires an organization**, and **ORGADMIN** must enable replication on the accounts.
- Billing covers **data transfer** (cross-region or cross-cloud egress) plus **compute** for refreshes, which runs serverless.
- Refreshes are **incremental**: only changed micro-partitions are copied after the initial copy.
- Secondary databases are **read-only** until they're promoted, which needs a failover group.
- Some objects have replication limitations (for example, some external objects, or temporary objects). Check the docs.

> **Exam trap:** **Database replication is available in every edition**, but **failover/failback and Client Redirect need Business Critical**.

> **Exam trap:** Replication is how you **share data across regions or clouds**. Direct shares only work **within the same region**.

## 8.6 Choosing a data protection option

| Scenario | Use |
|---|---|
| Accidentally deleted rows 2 hours ago | Time Travel: `INSERT ... SELECT ... BEFORE(STATEMENT => ...)` or clone |
| Dropped a table yesterday | `UNDROP TABLE` (within retention) |
| Need data from 20 days ago on Enterprise with 30-day retention | Time Travel |
| Data lost beyond Time Travel, within 7 days | Contact **Snowflake Support** (Fail-safe), permanent tables only |
| Need a dev/test copy of production instantly | Zero-copy clone |
| Regional outage protection | Replication + failover group [Business Critical+] |
| Rebuildable staging data, minimizing storage | Transient tables (no Fail-safe) |

## Self-check

**1. What is the maximum Time Travel retention in Enterprise edition, and for transient tables?**
<details><summary>Answer</summary><b>90 days</b> for permanent objects in Enterprise+. <b>1 day</b> for transient (and temporary) tables, in every edition.</details>

**2. Who can recover data from Fail-safe?**
<details><summary>Answer</summary>Only <b>Snowflake Support</b>.</details>

**3. What happens to a stream when its table's database is cloned?**
<details><summary>Answer</summary>The stream is cloned, but the clone starts fresh. Changes the source stream hadn't consumed aren't available in the clone.</details>

**4. Does a cloned table inherit the grants on the source table?**
<details><summary>Answer</summary>Not for a standalone table clone, unless you use <code>COPY GRANTS</code>. Child objects inside a cloned database or schema do keep their grants.</details>

**5. Which edition is needed to promote a secondary database to primary through failover?**
<details><summary>Answer</summary><b>Business Critical+</b>, using failover groups.</details>

**6. What unit does `AT(OFFSET => ...)` use?**
<details><summary>Answer</summary><b>Seconds</b>, as a negative number for the past.</details>
