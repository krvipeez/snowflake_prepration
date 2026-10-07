# 14 — Practice Questions (60)

Questions are grouped by exam domain, in roughly the same proportions as the real exam. Each one is either **single answer** or **"select N"**. Answers and explanations are in collapsible blocks.

**How to use it:** set a timer for **70 minutes**, which is the real exam's pace of about 69 seconds per question. Write down your answers, then check them all at the end and use the scoring guide.

| Domain | Questions | Count |
|---|---|---|
| 1 — Features and Architecture | Q1–Q15 | 15 |
| 2 — Account Access and Security | Q16–Q27 | 12 |
| 3 — Performance Concepts | Q28–Q36 | 9 |
| 4 — Data Loading and Unloading | Q37–Q42 | 6 |
| 5 — Data Transformations | Q43–Q54 | 12 |
| 6 — Data Protection and Data Sharing | Q55–Q60 | 6 |

---

## Domain 1 — Features and Architecture

**Q1.** Which layer of the Snowflake architecture is responsible for query parsing and optimization?
- A. Database storage
- B. Query processing (virtual warehouses)
- C. Cloud services
- D. The client driver

<details><summary>Answer</summary>

**C.** Cloud services compiles and optimizes queries. The virtual warehouse only executes the resulting plan.
</details>

**Q2.** Which TWO statements describe Snowflake's architecture? (Select 2)
- A. It is a pure shared-nothing architecture.
- B. It combines a central data repository with MPP compute clusters.
- C. Storage and compute can scale independently.
- D. Each virtual warehouse stores its own copy of table data.
- E. Customers can access the micro-partition files directly in cloud storage.

<details><summary>Answer</summary>

**B, C.** Snowflake is a hybrid of shared-disk (central storage) and shared-nothing (MPP warehouses). Warehouses share one copy of the data, holding only a local cache, and customers can't access the storage files directly.
</details>

**Q3.** What is the minimum edition that supports multi-cluster virtual warehouses?
- A. Standard
- B. Enterprise
- C. Business Critical
- D. Virtual Private Snowflake

<details><summary>Answer</summary>

**B. Enterprise.**
</details>

**Q4.** A company needs to manage its own encryption key, combined with a Snowflake-maintained key, so that it can revoke access to its data. Which feature and minimum edition apply?
- A. Periodic rekeying, Enterprise
- B. Tri-Secret Secure, Business Critical
- C. Client-side encryption, Standard
- D. Tri-Secret Secure, Enterprise

<details><summary>Answer</summary>

**B.** Tri-Secret Secure builds a composite master key from a customer-managed key and a Snowflake-managed key. It needs Business Critical or higher.
</details>

**Q5.** On a daily basis, a virtual warehouse uses 200 credits and cloud services use 26 credits. How many cloud services credits are billed for that day?
- A. 0
- B. 6
- C. 20
- D. 26

<details><summary>Answer</summary>

**B.** The free allowance is 10% of warehouse usage: 10% × 200 = 20. Only 26 − 20 = 6 credits are billed.
</details>

**Q6.** Which cloud platforms can host a Snowflake account? (Select 3)
- A. Amazon Web Services
- B. Oracle Cloud Infrastructure
- C. Microsoft Azure
- D. Google Cloud
- E. An on-premises data center

<details><summary>Answer</summary>

**A, C, D.** Snowflake runs only on AWS, Azure, and GCP.
</details>

**Q7.** A Medium warehouse is resumed, runs one query for 20 seconds, and is then suspended manually. How many credits are charged?
- A. 4/180 credits (20 seconds)
- B. 4/60 credits (60 seconds)
- C. 4 credits (one hour)
- D. 0, because the query finished in under a minute

<details><summary>Answer</summary>

**B.** A Medium uses 4 credits per hour, and every resume is billed for at least 60 seconds: 4 × 60/3600 = 4/60 ≈ 0.067 credits.
</details>

**Q8.** What is the maximum Time Travel retention for a **transient** table in an Enterprise edition account?
- A. 0 days
- B. 1 day
- C. 7 days
- D. 90 days

<details><summary>Answer</summary>

**B.** Transient and temporary tables allow 0 or 1 day in any edition. The 90-day maximum applies to permanent objects in Enterprise+.
</details>

**Q9.** Which TWO statements about temporary tables are true? (Select 2)
- A. They persist until explicitly dropped.
- B. They exist only for the duration of the session that created them.
- C. They have a 7-day Fail-safe period.
- D. They have no Fail-safe period.
- E. Other users can query them if they have SELECT privilege.

<details><summary>Answer</summary>

**B, D.** Temporary tables are session-scoped, are visible only to that session, and have no Fail-safe.
</details>

**Q10.** Which statement about micro-partitions is correct?
- A. Users define partition boundaries with PARTITION BY when creating a table.
- B. They hold 50–500 MB of uncompressed data and are immutable.
- C. They are row-oriented to speed up DML.
- D. They can be modified in place by UPDATE statements.

<details><summary>Answer</summary>

**B.** Micro-partitions are created automatically, columnar, and immutable. DML writes new micro-partitions.
</details>

**Q11.** Which constraint is enforced on a standard Snowflake table?
- A. PRIMARY KEY
- B. UNIQUE
- C. FOREIGN KEY
- D. NOT NULL

<details><summary>Answer</summary>

**D.** Only NOT NULL is enforced on standard tables. The others are informational, though hybrid tables do enforce them.
</details>

**Q12.** Which views can be added to a share?
- A. Standard views only
- B. Secure views and secure materialized views
- C. Materialized views only
- D. Any view, if the consumer is in the same region

<details><summary>Answer</summary>

**B.** Only secure objects (secure views, secure MVs, secure UDFs) can be granted to a share.
</details>

**Q13.** Which objects can be cloned? (Select 3)
- A. Database
- B. Schema
- C. Virtual warehouse
- D. Table
- E. User

<details><summary>Answer</summary>

**A, B, D.** Warehouses, users, and roles are account-level objects that aren't cloneable.
</details>

**Q14.** What is required to use Partner Connect?
- A. SYSADMIN role
- B. ACCOUNTADMIN role
- C. Business Critical edition
- D. A reader account

<details><summary>Answer</summary>

**B.** Partner Connect needs the ACCOUNTADMIN role (and a verified email address).
</details>

**Q15.** Which statement about Virtual Private Snowflake (VPS) is correct?
- A. It is the only edition that supports Time Travel.
- B. It provides a completely separate Snowflake environment, isolated from all other accounts.
- C. It is required for PrivateLink.
- D. It removes the need for virtual warehouses.

<details><summary>Answer</summary>

**B.** VPS runs on dedicated, isolated infrastructure, including its own metadata store. PrivateLink only needs Business Critical.
</details>

---

## Domain 2 — Account Access and Security

**Q16.** Following best practice, which role should custom roles be granted to?
- A. PUBLIC
- B. USERADMIN
- C. SYSADMIN
- D. ORGADMIN

<details><summary>Answer</summary>

**C.** Granting custom roles to SYSADMIN means SYSADMIN (and ACCOUNTADMIN above it) can manage every object those roles own.
</details>

**Q17.** Which is the lowest-privileged system-defined role that can create users and roles by default?
- A. USERADMIN
- B. SECURITYADMIN
- C. SYSADMIN
- D. ACCOUNTADMIN

<details><summary>Answer</summary>

**A.** USERADMIN has CREATE USER and CREATE ROLE. SECURITYADMIN inherits USERADMIN and adds MANAGE GRANTS.
</details>

**Q18.** Which privilege lets a role grant or revoke privileges on any object, even without owning it?
- A. OWNERSHIP
- B. MANAGE GRANTS
- C. MODIFY
- D. APPLY

<details><summary>Answer</summary>

**B.** MANAGE GRANTS, which SECURITYADMIN holds by default.
</details>

**Q19.** An account network policy allows `10.0.0.0/8`. User JDOE has a user-level network policy that allows only `192.168.1.0/24`. JDOE connects from `10.1.2.3`. What happens?
- A. Allowed, because the account policy permits it
- B. Blocked, because the user-level policy takes precedence
- C. Allowed, because the most permissive policy wins
- D. Blocked, because two policies can't coexist

<details><summary>Answer</summary>

**B.** A user-level policy overrides the account-level policy for that user.
</details>

**Q20.** Which TWO features need at least Enterprise edition? (Select 2)
- A. Dynamic data masking policies
- B. Secure views
- C. Row access policies
- D. Network policies
- E. Key-pair authentication

<details><summary>Answer</summary>

**A, C.** Secure views, network policies, and key-pair authentication are available in Standard.
</details>

**Q21.** A table has both a row access policy and a masking policy. In what order are they applied?
- A. Masking policy first, then row access policy
- B. Row access policy first, then masking policy
- C. In the order they were attached
- D. Only the most recently attached policy applies

<details><summary>Answer</summary>

**B.** Rows are filtered first, then columns are masked.
</details>

**Q22.** What is SCIM used for in Snowflake?
- A. Single sign-on through SAML
- B. Automated provisioning of users and roles from an identity provider
- C. Multi-factor authentication
- D. Encrypting data in transit

<details><summary>Answer</summary>

**B.** SCIM automates user and group provisioning (for example from Okta or Microsoft Entra ID). It isn't an authentication method.
</details>

**Q23.** In a managed access schema, which roles can grant SELECT on a table in that schema? (Select 2)
- A. The table owner
- B. The schema owner
- C. Any role with MANAGE GRANTS
- D. Any role with USAGE on the schema
- E. PUBLIC

<details><summary>Answer</summary>

**B, C.** In managed access schemas, grant decisions are centralized with the schema owner and MANAGE GRANTS holders. Object owners lose the ability to grant.
</details>

**Q24.** A role was given `GRANT SELECT ON ALL TABLES IN SCHEMA s TO ROLE r`. A new table is then created in schema `s`. Can role `r` query it?
- A. Yes, ALL includes future tables.
- B. No. A FUTURE grant was also needed.
- C. Yes, if the role has USAGE on the warehouse.
- D. Only if the table is transient.

<details><summary>Answer</summary>

**B.** `ON ALL` covers only existing objects. Use `GRANT SELECT ON FUTURE TABLES IN SCHEMA s TO ROLE r` for new ones.
</details>

**Q25.** Which statements about Snowflake encryption are true? (Select 2)
- A. Data at rest is encrypted with AES-256 in every edition.
- B. Encryption at rest can be disabled to improve performance.
- C. Snowflake-managed keys are rotated every 30 days.
- D. Periodic rekeying is available in Standard edition.
- E. Tri-Secret Secure is available in Enterprise edition.

<details><summary>Answer</summary>

**A, C.** Encryption is always on. Periodic rekeying needs Enterprise+, and Tri-Secret Secure needs Business Critical+.
</details>

**Q26.** A service account must connect to Snowflake from a pipeline without a password, and its credentials must be rotatable without downtime. What is the best option?
- A. Username and password with MFA
- B. Key-pair authentication using RSA_PUBLIC_KEY and RSA_PUBLIC_KEY_2
- C. SAML SSO
- D. SCIM

<details><summary>Answer</summary>

**B.** Key-pair authentication supports two public keys per user, so a new key can be added before the old one is removed.
</details>

**Q27.** Which privilege on a warehouse allows a role to suspend and resume it, but not resize it?
- A. USAGE
- B. MONITOR
- C. OPERATE
- D. MODIFY

<details><summary>Answer</summary>

**C.** OPERATE covers start, stop, suspend, resume, and cancelling queries. MODIFY is needed to resize.
</details>

---

## Domain 3 — Performance Concepts

**Q28.** BI dashboards slow down every morning at 9 AM, when 200 users log in. The Query Profile shows fast execution, but queries spend a long time queued. What is the best fix?
- A. Increase the warehouse size.
- B. Configure a multi-cluster warehouse in auto-scale mode.
- C. Add a clustering key.
- D. Disable the result cache.

<details><summary>Answer</summary>

**B.** Queuing means a concurrency problem, which is solved by scaling out. This requires Enterprise+.
</details>

**Q29.** A single large query shows significant "Bytes spilled to remote storage". What should you do first?
- A. Increase MAX_CLUSTER_COUNT.
- B. Run the query on a larger warehouse.
- C. Enable search optimization.
- D. Increase AUTO_SUSPEND.

<details><summary>Answer</summary>

**B.** Spilling means the warehouse lacks memory and local disk. Scale up.
</details>

**Q30.** Which conditions must be true for a query to reuse the query result cache? (Select 2)
- A. The query text is identical to an earlier query.
- B. The same virtual warehouse is used.
- C. The underlying data hasn't changed.
- D. The same user runs the query.
- E. The warehouse hasn't been suspended since the earlier query.

<details><summary>Answer</summary>

**A, C.** The result cache lives in cloud services. It is independent of the warehouse, and of the user, as long as the role has the needed privileges.
</details>

**Q31.** How long is a result kept in the query result cache if it is never reused?
- A. 1 hour
- B. 24 hours
- C. 7 days
- D. 31 days

<details><summary>Answer</summary>

**B.** 24 hours. Each reuse resets the period, up to a maximum of 31 days.
</details>

**Q32.** What happens to the warehouse (local disk) cache when a warehouse is suspended?
- A. It is kept for 24 hours.
- B. It is moved to the result cache.
- C. It is dropped.
- D. It is kept until the next resume.

<details><summary>Answer</summary>

**C.** The local SSD cache is lost when a warehouse is suspended.
</details>

**Q33.** `SYSTEM$CLUSTERING_INFORMATION` on a 10 TB table returns an `average_depth` of 450 for the date column used in most filters. What does this indicate, and what could help?
- A. Excellent clustering; no action needed
- B. Poor clustering; consider defining a clustering key on the date column
- C. The table is too small to cluster
- D. Search optimization is required

<details><summary>Answer</summary>

**B.** High depth means many overlapping micro-partitions and poor pruning. A clustering key on the filtered column, kept up by Automatic Clustering, improves it.
</details>

**Q34.** Which workload benefits most from the Search Optimization Service?
- A. Aggregating an entire fact table by month
- B. Selective equality lookups that return a few rows from a very large table
- C. Loading files from S3
- D. Complex multi-table joins with large intermediate results

<details><summary>Answer</summary>

**B.** Search optimization targets highly selective point lookups (as well as substring, VARIANT, and geo searches).
</details>

**Q35.** Which statements about resource monitors are true? (Select 2)
- A. They can be created by SYSADMIN.
- B. A warehouse can be assigned to only one resource monitor.
- C. SUSPEND_IMMEDIATE cancels running queries.
- D. They limit credits consumed by Snowpipe.
- E. They can only be set at account level.

<details><summary>Answer</summary>

**B, C.** Only ACCOUNTADMIN creates resource monitors. They control user-managed warehouses only (not serverless features), and they can be set at account or warehouse level.
</details>

**Q36.** A query on a 5 TB table shows Partitions scanned = 48,900 of 50,000, with a filter `WHERE TO_CHAR(order_date, 'YYYY-MM') = '2024-06'`. What is the most effective first step?
- A. Scale the warehouse up.
- B. Rewrite the filter as a range on `order_date`, then evaluate clustering.
- C. Enable multi-cluster.
- D. Increase STATEMENT_TIMEOUT_IN_SECONDS.

<details><summary>Answer</summary>

**B.** The function on the column defeats pruning. A plain range predicate (`order_date >= '2024-06-01' AND order_date < '2024-07-01'`) lets MIN/MAX metadata prune partitions.
</details>

---

## Domain 4 — Data Loading and Unloading

**Q37.** What are the default ON_ERROR settings for bulk COPY INTO and for Snowpipe?
- A. CONTINUE / SKIP_FILE
- B. ABORT_STATEMENT / SKIP_FILE
- C. SKIP_FILE / ABORT_STATEMENT
- D. ABORT_STATEMENT / ABORT_STATEMENT

<details><summary>Answer</summary>

**B.**
</details>

**Q38.** A COPY INTO statement that loaded files successfully yesterday is run again against the same stage path. No files have changed. What happens?
- A. All files load again, duplicating rows.
- B. The files are skipped because of load metadata.
- C. The statement fails with an error.
- D. The table is truncated and reloaded.

<details><summary>Answer</summary>

**B.** Load metadata (64 days) stops unchanged files being loaded again. `FORCE = TRUE` would override it.
</details>

**Q39.** What file size does Snowflake recommend for efficient parallel loading?
- A. 1–10 MB uncompressed
- B. 100–250 MB compressed
- C. 1–5 GB compressed
- D. Exactly 16 MB

<details><summary>Answer</summary>

**B.**
</details>

**Q40.** Which statements about PUT are true? (Select 2)
- A. It uploads files to internal stages.
- B. It uploads files to external S3 stages.
- C. It can be run from a client such as SnowSQL or a driver.
- D. It runs from a Snowsight worksheet.
- E. It loads data into a table.

<details><summary>Answer</summary>

**A, C.** PUT only stages files to internal stages, from a client. A separate COPY then loads them into a table.
</details>

**Q41.** A data engineer wants to check staged files for errors without loading any data. Which option should be used?
- A. ON_ERROR = CONTINUE
- B. VALIDATION_MODE = RETURN_ERRORS
- C. PURGE = TRUE
- D. FORCE = TRUE

<details><summary>Answer</summary>

**B.** VALIDATION_MODE runs a dry-run validation. Note that it can't be used with a transforming COPY.
</details>

**Q42.** A table must be unloaded to exactly one Parquet file. Which option is needed?
- A. MAX_FILE_SIZE = 0
- B. SINGLE = TRUE
- C. OVERWRITE = TRUE
- D. PARTITION BY (NULL)

<details><summary>Answer</summary>

**B.** By default an unload writes multiple files in parallel. SINGLE = TRUE writes one file, which is still limited by MAX_FILE_SIZE (up to 5 GB).
</details>

---

## Domain 5 — Data Transformations

**Q43.** Which FLATTEN output column contains the position of an element within an array?
- A. KEY
- B. PATH
- C. INDEX
- D. SEQ

<details><summary>Answer</summary>

**C.**
</details>

**Q44.** `SELECT v:customer.name FROM raw` returns `"Alice"` with double quotes. How do you return `Alice`?
- A. `v:customer.name::STRING`
- B. `TRIM(v:customer.name)`
- C. `v:customer.NAME`
- D. `PARSE_JSON(v:customer.name)`

<details><summary>Answer</summary>

**A.** Casting the VARIANT to STRING removes the JSON quoting.
</details>

**Q45.** A JSON document contains the key `"OrderID"`. Which expression returns its value?
- A. `v:orderid`
- B. `v:ORDERID`
- C. `v:OrderID`
- D. All of the above

<details><summary>Answer</summary>

**C.** Element names in semi-structured paths are case-sensitive.
</details>

**Q46.** Which clause filters rows on the result of a window function, without needing a subquery?
- A. HAVING
- B. QUALIFY
- C. WHERE
- D. FILTER

<details><summary>Answer</summary>

**B.**
</details>

**Q47.** A MERGE statement fails with a "duplicate row detected" (non-deterministic) error. What is the most likely cause?
- A. The target table has no primary key.
- B. Several source rows match the same target row for an UPDATE or DELETE.
- C. The MERGE has no WHEN NOT MATCHED clause.
- D. The warehouse is too small.

<details><summary>Answer</summary>

**B.** `ERROR_ON_NONDETERMINISTIC_MERGE` defaults to TRUE. Deduplicate the source first, for example with QUALIFY ROW_NUMBER() = 1.
</details>

**Q48.** A row in a table with a standard stream is updated. What does the stream show?
- A. One row with METADATA$ACTION = 'UPDATE'
- B. Two rows: DELETE and INSERT, both with METADATA$ISUPDATE = TRUE
- C. One INSERT row with METADATA$ISUPDATE = FALSE
- D. Nothing; standard streams don't capture updates

<details><summary>Answer</summary>

**B.** There is no 'UPDATE' action value. Updates are shown as a DELETE + INSERT pair.
</details>

**Q49.** Which action advances a stream's offset?
- A. `SELECT * FROM my_stream`
- B. `SHOW STREAMS`
- C. `INSERT INTO target SELECT * FROM my_stream` (committed)
- D. `DESCRIBE STREAM my_stream`

<details><summary>Answer</summary>

**C.** Only a DML statement that reads the stream and commits consumes it.
</details>

**Q50.** A newly created task never runs. What are the two most likely reasons? (Select 2)
- A. The task was never resumed.
- B. The task owner lacks the EXECUTE TASK privilege.
- C. Tasks need Enterprise edition.
- D. Tasks can only run on serverless compute.
- E. The task's WHEN clause must reference a stream.

<details><summary>Answer</summary>

**A, B.** Tasks are created suspended, and resuming or running them needs EXECUTE TASK. Tasks are [Standard+], and a WHEN clause is optional.
</details>

**Q51.** Which statement about stored procedures and UDFs is correct?
- A. UDFs can run DDL statements.
- B. Stored procedures can be called inside a SELECT list.
- C. Stored procedures can run DDL and DML, and are invoked with CALL.
- D. UDFs can only be written in SQL.

<details><summary>Answer</summary>

**C.**
</details>

**Q52.** A team wants a declarative pipeline where a summary table is kept no more than 10 minutes behind its source tables, including joins, without writing MERGE logic. What should they use?
- A. A materialized view
- B. A dynamic table with TARGET_LAG = '10 minutes'
- C. A stream with an append-only setting
- D. A secure view

<details><summary>Answer</summary>

**B.** Dynamic tables support joins and refresh automatically within the target lag. Materialized views can't contain joins.
</details>

**Q53.** An application needs to give users with no Snowflake account temporary access to download a PDF stored in a stage. Which function should it use?
- A. BUILD_SCOPED_FILE_URL
- B. BUILD_STAGE_FILE_URL
- C. GET_PRESIGNED_URL
- D. GET_STAGE_LOCATION

<details><summary>Answer</summary>

**C.** Pre-signed URLs can be used by anyone with the link until they expire. Scoped and file URLs need Snowflake authentication.
</details>

**Q54.** Which function returns an approximate distinct count using HyperLogLog?
- A. COUNT(DISTINCT x)
- B. APPROX_COUNT_DISTINCT(x)
- C. APPROX_TOP_K(x)
- D. MINHASH(x)

<details><summary>Answer</summary>

**B.**
</details>

---

## Domain 6 — Data Protection and Data Sharing

**Q55.** A permanent table in an Enterprise account has DATA_RETENTION_TIME_IN_DAYS = 30. It was dropped 33 days ago. How can the data be recovered?
- A. UNDROP TABLE
- B. A clone using AT(OFFSET => ...)
- C. A request to Snowflake Support (Fail-safe)
- D. It can't be recovered.

<details><summary>Answer</summary>

**C.** The data left Time Travel after 30 days and is now on day 3 of the 7-day Fail-safe period. Only Snowflake Support can recover it.
</details>

**Q56.** Which statements about zero-copy cloning are true? (Select 2)
- A. A clone initially uses no additional storage.
- B. A cloned table keeps all privileges granted on the source table by default.
- C. Load metadata isn't copied, so the same files can be loaded into the clone.
- D. Cloning needs a running warehouse that scans all data.
- E. Transient tables can be cloned as permanent tables.

<details><summary>Answer</summary>

**A, C.** A standalone table clone doesn't keep the source's own grants unless COPY GRANTS is used. Cloning is a metadata operation. Transient → permanent cloning isn't allowed.
</details>

**Q57.** Which can a consumer do with a database created from a share? (Select 2)
- A. Query the shared tables with its own warehouse.
- B. Clone the shared database.
- C. Join shared tables with its own tables.
- D. Use Time Travel on shared tables.
- E. Re-share the data with another account.

<details><summary>Answer</summary>

**A, C.**
</details>

**Q58.** A provider wants to share data with a partner that has no Snowflake account. What should the provider do, and who pays for compute?
- A. Create a reader account; the provider pays.
- B. Create a reader account; the partner pays.
- C. Publish a Marketplace listing; the partner pays.
- D. Unload the data to S3; nobody pays.

<details><summary>Answer</summary>

**A.** Reader accounts are created and paid for by the provider.
</details>

**Q59.** A provider in AWS us-east-1 must share data with a consumer account in Azure West Europe. What is required?
- A. Nothing; direct shares work across clouds.
- B. Replicate the data to an account in the consumer's region (or use a listing with Cross-Cloud Auto-Fulfillment).
- C. A reader account in us-east-1
- D. Business Critical edition for both accounts

<details><summary>Answer</summary>

**B.** Direct shares only work within one region.
</details>

**Q60.** Which capability needs Business Critical edition or higher?
- A. Database replication to another region
- B. Failover groups with Client Redirect
- C. Secure Data Sharing
- D. 90-day Time Travel

<details><summary>Answer</summary>

**B.** Database replication and sharing work in every edition, and 90-day Time Travel needs Enterprise.
</details>

---

## Scoring guide

1. Score **1 point** per question. Multi-select questions score a point only if **every** choice is right, as on the real exam, where there is no partial credit.
2. Use the table to judge readiness:

| Score | % | Readiness |
|---|---|---|
| 54–60 | 90%+ | **Ready.** Book the exam and keep revising the cheat sheet. |
| 48–53 | 80–89% | **Likely pass.** Revise the weakest domain and retake in 3–4 days. |
| 42–47 | 70–79% | **Borderline.** The real pass mark is about 75%, so spend a week on the weak domains. |
| < 42 | < 70% | **Not yet.** Redo the study plan sessions for the weak domains, plus hands-on cookbook work. |

3. Work out your score **per domain** too, because a weighted weak spot is dangerous:

| Domain | Your score | Out of | Target |
|---|---|---|---|
| 1 — Architecture | | 15 | ≥ 12 |
| 2 — Security | | 12 | ≥ 10 |
| 3 — Performance | | 9 | ≥ 7 |
| 4 — Loading | | 6 | ≥ 5 |
| 5 — Transformations | | 12 | ≥ 9 |
| 6 — Protection and Sharing | | 6 | ≥ 5 |

4. For every miss, write down **why** the right answer is right **and** why your choice was wrong. Most misses come from the "Exam trap" notes in each chapter.
