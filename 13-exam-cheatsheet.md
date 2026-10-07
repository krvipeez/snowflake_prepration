# 13 — Exam Cheat Sheet

Condensed revision for the last 48 hours, with one section per COF-C02 domain. For the numbers, see [16-numbers-and-limits.md](16-numbers-and-limits.md).

---

## Domain 1 — Features and Architecture (25%)

**Architecture**
- Hybrid **shared-disk** (central storage) + **shared-nothing** (MPP warehouses). Storage and compute scale independently.
- **Three layers:** storage (compressed columnar micro-partitions), compute (virtual warehouses), cloud services (authentication, metadata, optimizer, security, result cache, transactions).
- The optimizer runs in **cloud services**. Cloud services are billed only **above 10%** of daily warehouse credits.
- Runs on **AWS, Azure, GCP** only. An account lives in **one region**.
- Preferred account identifier: `orgname-accountname`. Legacy: account locator.

**Editions (minimum)**
- **[Enterprise+]:** multi-cluster, 90-day Time Travel, MVs, search optimization, QAS, masking, row access, tags, classification, access history, periodic rekeying.
- **[Business Critical+]:** Tri-Secret Secure, PrivateLink, HIPAA/PCI, failover groups, Client Redirect, account-object replication.
- **[VPS]:** fully isolated environment.
- Everything else (secure views, clustering, Snowpipe, streams, tasks, dynamic tables, sharing, replication of databases, resource monitors) is **[Standard+]**.

**Warehouses**
- Sizes double: XS=1, S=2, M=4, L=8, XL=16, 2XL=32, 3XL=64, 4XL=128, 5XL=256, 6XL=512 credits/hour.
- Billed **per second**, with a **60 s minimum** on each start or resume.
- Defaults: `AUTO_SUSPEND` 600 s, `AUTO_RESUME` TRUE.
- **Scale up** for complex queries and spilling. **Scale out** (multi-cluster [Enterprise+]) for concurrency and queuing.
- Multi-cluster: **Maximized** (min = max) vs **Auto-scale** (min < max). **Standard** policy favors performance; **Economy** favors cost (6 minutes of work before adding a cluster).
- Snowpark-optimized: about 16x memory per node.

**Caches**
- **Result cache**: cloud services, 24 h, up to 31 days with reuse, shared across users and warehouses, needs identical SQL and unchanged data.
- **Warehouse cache**: SSD, lost on suspend.
- **Metadata cache**: `COUNT`/`MIN`/`MAX` with no warehouse needed.

**Storage and objects**
- Micro-partitions: **50–500 MB uncompressed**, columnar, **immutable**, automatic.
- Only **NOT NULL** is enforced (on standard tables).
- Table types: permanent (Fail-safe 7 days), **transient / temporary (no Fail-safe, Time Travel ≤ 1 day)**, external (read-only), dynamic, Iceberg, hybrid.
- Views: standard; **secure** (hidden definition, shareable) [Standard+]; **materialized** [Enterprise+] (single table, serverless refresh, always current).
- Stages: `@~` user, `@%t` table (no transforms), `@name` internal or external.

---

## Domain 2 — Account Access and Security (20%)

- **DAC + RBAC**. Privileges go to roles, roles go to users or roles, and privileges are **inherited upward**.
- Hierarchy: **ACCOUNTADMIN** ⊃ SECURITYADMIN ⊃ USERADMIN; ACCOUNTADMIN ⊃ SYSADMIN ⊃ custom roles. **PUBLIC** is granted to everyone. **ORGADMIN** manages the organization.
- **USERADMIN** creates users and roles. **SECURITYADMIN** has `MANAGE GRANTS`. **SYSADMIN** creates warehouses and databases. Grant custom roles **to SYSADMIN**.
- Querying a table needs: warehouse `USAGE` + database `USAGE` + schema `USAGE` + table `SELECT`.
- `ON ALL` = existing objects only; `ON FUTURE` = new objects. Schema-level future grants beat database-level ones.
- **Managed access schema**: only the schema owner or `MANAGE GRANTS` can grant.
- Warehouse privileges: `USAGE`, `OPERATE` (start, stop, cancel), `MODIFY` (resize), `MONITOR`.
- Authentication: password + **MFA** (Duo), **SAML SSO**, **OAuth** (Snowflake / External), **key-pair** (RSA ≥ 2048, two keys for rotation). **SCIM** = provisioning, not authentication.
- **Network policies**: account, user, or integration level. **User overrides account.** Blocked list beats allowed list. SECURITYADMIN+.
- **Encryption**: AES-256 at rest, TLS 1.2+ in transit, hierarchical keys (root → account → table → file), **30-day rotation** [Standard+], **annual rekeying** [Enterprise+], **Tri-Secret Secure** [Business Critical+].
- **Masking policies** and **row access policies** [Enterprise+]. Row access is evaluated **first**. One masking policy per column, one row access policy per table. Tag-based masking. External tokenization.
- Secure views are the Standard-edition way to restrict rows and columns.

---

## Domain 3 — Performance Concepts (15%)

- **Query Profile**: watch **spilling** (scale up), **partitions scanned vs total** (pruning), **exploding joins**, **queued time** (scale out), **percentage scanned from cache**.
- **Pruning** uses MIN/MAX metadata. Functions on filter columns can defeat it.
- **Clustering keys** [Standard+]: for multi-TB tables; 3–4 columns max, ordered low → high cardinality; serverless **Automatic Clustering**; check with `SYSTEM$CLUSTERING_INFORMATION` / `_DEPTH` (lower depth is better).
- **Search optimization** [Enterprise+]: selective point lookups, substring, VARIANT, geo.
- **QAS** [Enterprise+]: outlier large-scan queries; `QUERY_ACCELERATION_MAX_SCALE_FACTOR` defaults to 8.
- **Materialized views** [Enterprise+]: repeated aggregation on one table.
- **Resource monitors**: ACCOUNTADMIN only; account- or warehouse-level; one per warehouse; `NOTIFY` / `SUSPEND` (lets running queries finish) / `SUSPEND_IMMEDIATE` (cancels); **don't cover serverless**.
- Timeouts: `STATEMENT_TIMEOUT_IN_SECONDS` defaults to 172,800 (2 days); the lower of session and warehouse values wins. `MAX_CONCURRENCY_LEVEL` defaults to 8.

---

## Domain 4 — Data Loading and Unloading (10%)

- `PUT` (upload) and `GET` (download) work with **internal stages only**, from a **client** (not a Snowsight worksheet). PUT gzips by default.
- `COPY INTO <table>` uses a warehouse; load metadata lasts **64 days**, so files aren't reloaded unless `FORCE = TRUE`. Use `LOAD_UNCERTAIN_FILES` for files older than 64 days.
- `ON_ERROR`: COPY defaults to **ABORT_STATEMENT**, Snowpipe to **SKIP_FILE**. Others: CONTINUE, SKIP_FILE_n, 'SKIP_FILE_n%'.
- `VALIDATION_MODE` (RETURN_n_ROWS, RETURN_ERRORS, RETURN_ALL_ERRORS) **loads nothing** and can't be used with a transforming COPY. `VALIDATE()` checks past loads.
- COPY transformations: reorder, omit, cast, `$1`, `METADATA$FILENAME`. **No** WHERE, JOIN, GROUP BY, or FLATTEN.
- `FILES` takes up to **1,000** names; `PATTERN` takes a regex.
- **Snowpipe**: serverless, auto-ingest through cloud notifications (**external stages only**) or the REST API (internal or external), **14-day** load history, no ordering guarantee, `ALTER PIPE ... REFRESH` covers the last **7 days**.
- Files of **100–250 MB compressed**.
- **Unload**: `COPY INTO @stage`; CSV, JSON, Parquet only; parallel multiple files by default; `SINGLE = TRUE` for one; `MAX_FILE_SIZE` defaults to **16 MB** (max 5 GB); JSON needs a single VARIANT/OBJECT column; `PARTITION BY`.
- File format precedence: COPY statement > stage > table.

---

## Domain 5 — Data Transformations (20%)

- `VARIANT` / `OBJECT` / `ARRAY`; 16 MB per value (classic limit). Formats: JSON, Avro, ORC, Parquet, XML.
- Paths: `v:a.b`, `v['a']`, `v:arr[0]`. **Keys are case-sensitive.** Cast `::STRING` to remove quotes. A missing path returns NULL. JSON null ≠ SQL NULL.
- **FLATTEN** columns: SEQ, KEY, PATH, **INDEX**, **VALUE**, THIS. Arguments: INPUT, PATH, **OUTER** (keep empty), **RECURSIVE**, MODE. Use with `LATERAL`.
- `OBJECT_CONSTRUCT` drops NULLs; `ARRAY_AGG` builds arrays; `PARSE_JSON` / `TRY_PARSE_JSON`.
- **QUALIFY** filters window results. **MERGE** fails on duplicate source matches by default. `INSERT ALL` / `INSERT FIRST`; `PIVOT` / `UNPIVOT`.
- Sampling: BERNOULLI/ROW (per row) vs SYSTEM/BLOCK (per block). Approximations: HyperLogLog (`APPROX_COUNT_DISTINCT`), `APPROX_TOP_K`, `APPROX_PERCENTILE`.
- **Streams**: standard / append-only / insert-only (external). `METADATA$ACTION`, `$ISUPDATE`, `$ROW_ID`. Updates show up as DELETE + INSERT. Consumed only by **committed DML**. Stale after retention (extended up to 14 days).
- **Tasks**: created **suspended**; `EXECUTE TASK` privilege; serverless also needs `EXECUTE MANAGED TASK`; CRON or `n MINUTE`; DAG root + `AFTER`; `WHEN SYSTEM$STREAM_HAS_DATA` skips runs with no data.
- **Dynamic tables**: declarative, `TARGET_LAG` (or DOWNSTREAM), use a warehouse, no DML.
- **UDF** (inside SQL, no DDL or DML) vs **procedure** (`CALL`, DDL and DML, owner's rights by default). Languages: SQL, JavaScript (UPPERCASE arguments), Python, Java, Scala. External functions use API integrations.
- **Snowpark**: lazy DataFrames executed in Snowflake.
- **Unstructured**: directory tables; **scoped URL** (24 h, the generating user only), **file URL** (permanent, role-based), **pre-signed URL** (anyone, set expiry).

---

## Domain 6 — Data Protection and Data Sharing (10%)

- **Time Travel**: default 1 day; Standard max 1; **Enterprise max 90** (permanent); transient and temporary max 1. `AT` / `BEFORE` with `TIMESTAMP`, `OFFSET` (**seconds**), `STATEMENT`. `UNDROP` for tables, schemas, databases (and some account objects).
- **Fail-safe**: **7 days**, permanent tables only, **Snowflake Support only**, not queryable.
- **Cloning**: zero-copy, metadata only, storage only for changes. The clone doesn't keep the source's own grants (children in a cloned container do). Load metadata isn't copied. Cloned tasks are suspended. Internal named stages aren't cloned. You can't clone transient → permanent.
- **Replication**: databases and shares in **all editions**. Failover groups, Client Redirect, and account objects need **[Business Critical+]**. Secondaries are read-only. ORGADMIN enables replication.
- **Sharing**: no data copied; the provider pays storage, the consumer pays compute. Only **secure** views and UDFs can be shared. Consumers can't clone, Time Travel, re-share, or modify. `IMPORTED PRIVILEGES`. Same region only; otherwise replicate or use a listing with auto-fulfillment.
- **Reader accounts**: for consumers without Snowflake; **the provider pays compute**; read-only; no loading.
- **Listings**: private or Marketplace (public); free, limited trial, paid, personalized; Native Apps.

---

## Last-minute "which one?" table

| If the question says… | Answer |
|---|---|
| "Queries are queuing" | Multi-cluster warehouse (scale out) |
| "Spilling to remote storage" | Bigger warehouse (scale up) |
| "Same query re-run, no data change, instant" | Result cache |
| "Recover a table dropped yesterday" | `UNDROP TABLE` |
| "Data lost 5 days after the Time Travel window" | Fail-safe through Snowflake Support |
| "Instant dev copy, no extra storage" | Zero-copy clone |
| "Hide the view definition from consumers" | Secure view |
| "Mask a column per role" | Masking policy [Enterprise+] |
| "Customer-managed encryption key" | Tri-Secret Secure [Business Critical+] |
| "Traffic must not cross the public internet" | PrivateLink [Business Critical+] |
| "Continuous loading as files land in S3" | Snowpipe auto-ingest |
| "Point lookup on a huge table" | Search optimization [Enterprise+] |
| "Share with a company that has no Snowflake account" | Reader account |
| "Who accessed column X?" | `ACCESS_HISTORY` [Enterprise+] |
| "Real-time query history from the last hour" | `INFORMATION_SCHEMA.QUERY_HISTORY()` |
| "History older than 14 days, or dropped objects" | `SNOWFLAKE.ACCOUNT_USAGE` |
| "Create users with the least privilege" | USERADMIN |
| "Automated provisioning from Okta / Entra" | SCIM |
