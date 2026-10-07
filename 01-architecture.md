# 01 — Architecture

**Exam domain:** 1 (Features and Architecture, 25%)

## 1.1 What Snowflake is

Snowflake is a fully managed **SaaS** data platform that runs on public cloud infrastructure. Customers do not install, configure, or manage hardware or software; Snowflake handles upgrades, patching, tuning, and maintenance. [Standard+]

Snowflake's architecture is a **hybrid of shared-disk and shared-nothing**:

| Trait | Borrowed from | How Snowflake implements it |
|---|---|---|
| Single central data repository accessible from all compute | Shared-disk | One storage layer in cloud object storage |
| Independent compute clusters, each holding a local cache | Shared-nothing (MPP) | Virtual warehouses, each an MPP cluster |

The result is that **storage and compute scale independently**, and many warehouses can read the same data at once without contending with each other.

> **Exam trap:** Snowflake is *neither* purely shared-disk *nor* purely shared-nothing. Answers that say "shared-nothing only" or "shared-disk only" are wrong.

## 1.2 The three layers

```
 ┌──────────────────────────────────────────────────────────────┐
 │  CLOUD SERVICES  (the "brain")                               │
 │  Authentication · Access control · Infrastructure manager    │
 │  Metadata manager · Query parsing & optimization · Security  │
 │  Result cache · Transaction management                       │
 ├──────────────────────────────────────────────────────────────┤
 │  QUERY PROCESSING  (the "muscle")                            │
 │  Virtual warehouses = independent MPP compute clusters       │
 │  [WH_ETL]   [WH_BI]   [WH_DS]   ... local SSD cache each     │
 ├──────────────────────────────────────────────────────────────┤
 │  DATABASE STORAGE                                            │
 │  Compressed, columnar micro-partitions in cloud object store │
 │  (S3 / Azure Blob / GCS) — managed by Snowflake only         │
 └──────────────────────────────────────────────────────────────┘
```

| Layer | Responsibilities | Billed as | Customer control |
|---|---|---|---|
| **Database storage** | Stores table data as compressed, columnar, immutable micro-partitions; also stores Time Travel and Fail-safe data | Storage: average compressed TB per month | Retention settings, table types. The files cannot be accessed directly. |
| **Query processing** | Executes queries with virtual warehouses (and serverless compute for some features) | Compute credits, billed per second | Size, count, auto-suspend, scaling |
| **Cloud services** | Authentication, access control, metadata, query compilation and optimization, infrastructure management, result cache, transactions | Credits, **only the portion above 10% of daily warehouse usage** | None; fully managed |

> **Exam trap:** Query **optimization and compilation** happen in **cloud services**, not in the warehouse. The warehouse only **executes** the plan.

> **Exam trap:** Customers **cannot** see or access the underlying storage files. Data is reachable only through SQL and the Snowflake APIs.

> **Exam trap:** Metadata-only operations, such as `COUNT(*)`, `MIN`, or `MAX` on a whole table, or `SHOW` commands, are answered by cloud services from metadata. They can run **without a running warehouse**.

### Cloud services billing adjustment

Cloud services usage is charged **only if** it exceeds **10% of daily virtual warehouse compute**. The adjustment is calculated daily, in UTC. Serverless compute does **not** count toward the 10% base.

| Example day | Warehouse credits | Cloud services credits | Billed cloud services |
|---|---|---|---|
| A | 100 | 8 | 0 (8 ≤ 10) |
| B | 100 | 15 | 5 (15 − 10) |

## 1.3 Editions matrix

All editions include the core platform. Each higher edition includes everything in the editions below it.

| Feature | Standard | Enterprise | Business Critical | VPS |
|---|:-:|:-:|:-:|:-:|
| Full SQL, all data types, semi-structured support | ✔ | ✔ | ✔ | ✔ |
| Time Travel, **up to 1 day** | ✔ | ✔ | ✔ | ✔ |
| Time Travel, **up to 90 days** (extended) | | ✔ | ✔ | ✔ |
| Fail-safe (7 days, permanent tables) | ✔ | ✔ | ✔ | ✔ |
| Always-on encryption (AES-256), 30-day key rotation | ✔ | ✔ | ✔ | ✔ |
| Network policies, MFA, SSO, OAuth, key-pair authentication | ✔ | ✔ | ✔ | ✔ |
| Secure views, secure UDFs | ✔ | ✔ | ✔ | ✔ |
| Clustering keys and Automatic Clustering | ✔ | ✔ | ✔ | ✔ |
| Secure Data Sharing, reader accounts, Marketplace | ✔ | ✔ | ✔ | ✔ (see 09) |
| Snowpipe, streams, tasks, dynamic tables, Snowpark | ✔ | ✔ | ✔ | ✔ |
| Database and share replication | ✔ | ✔ | ✔ | ✔ |
| Resource monitors | ✔ | ✔ | ✔ | ✔ |
| **Multi-cluster warehouses** | | ✔ | ✔ | ✔ |
| **Materialized views** | | ✔ | ✔ | ✔ |
| **Search Optimization Service** | | ✔ | ✔ | ✔ |
| **Query Acceleration Service** | | ✔ | ✔ | ✔ |
| **Column-level security (masking policies, external tokenization)** | | ✔ | ✔ | ✔ |
| **Row access policies** | | ✔ | ✔ | ✔ |
| **Object tagging, tag-based masking, data classification** | | ✔ | ✔ | ✔ |
| **Access history** (`ACCESS_HISTORY` view) | | ✔ | ✔ | ✔ |
| **Periodic rekeying** of encrypted data (annual) | | ✔ | ✔ | ✔ |
| **Aggregation and projection policies** | | ✔ | ✔ | ✔ |
| **Tri-Secret Secure** (customer-managed key) | | | ✔ | ✔ |
| **Private connectivity** (AWS PrivateLink, Azure Private Link, GCP Private Service Connect) | | | ✔ | ✔ |
| **Support for PHI and regulated data** (HIPAA, HITRUST, PCI DSS) | | | ✔ | ✔ |
| **Failover and failback** (failover groups), **Client Redirect** | | | ✔ | ✔ |
| **Replication of account objects** (users, roles, warehouses, and so on) | | | ✔ | ✔ |
| Government regions (for example AWS GovCloud) | | | ✔ | ✔ |
| **Dedicated, isolated Snowflake environment** (separate metadata store and compute pool) | | | | ✔ |

Quick memory aid:

- **Enterprise** adds *scale and governance*: multi-cluster, 90-day Time Travel, materialized views, search optimization, query acceleration, masking, row access, tags, access history, rekeying.
- **Business Critical** adds *regulated and high-security workloads*: Tri-Secret Secure, PrivateLink, HIPAA/PCI, failover and Client Redirect.
- **VPS** adds *full isolation*: a dedicated environment that shares no hardware or metadata store with other accounts.

> **Exam trap:** **Secure views** are [Standard+]. **Materialized views** are [Enterprise+]. Exam distractors often swap the two.

> **Exam trap:** **Database replication** works in every edition, but **failover/failback** and **Client Redirect** need [Business Critical+].

> **Exam trap:** **Resource monitors** and **Automatic Clustering** are [Standard+]. **Multi-cluster warehouses** are [Enterprise+].

## 1.4 Clouds, regions, and accounts

### Supported clouds

| Cloud | Object storage behind Snowflake | Private connectivity [Business Critical+] |
|---|---|---|
| Amazon Web Services | Amazon S3 | AWS PrivateLink |
| Microsoft Azure | Azure Blob Storage | Azure Private Link |
| Google Cloud | Google Cloud Storage | Private Service Connect |

> **Exam trap:** Snowflake runs only on **AWS, Azure, and GCP**. It cannot be installed on-premises or on another cloud. Answers mentioning on-prem or other clouds are distractors.

### Accounts, regions, organizations

- An **account** lives in exactly **one cloud provider and one region**, which you choose when the account is created.
- An **organization** groups the accounts a customer owns. The **ORGADMIN** role, or a newer organization-level admin role where enabled, creates accounts, views organization-wide usage, and enables replication between accounts.
- Data sharing and replication **across regions or clouds** need replication (or listing auto-fulfillment) and incur **data transfer (egress)** charges.
- Region choice affects latency, data residency and compliance, available features, and price per credit.

### Account identifiers

| Format | Example | Notes |
|---|---|---|
| **Organization + account name** (preferred) | `myorg-myaccount` | Stable across regions; used in URLs such as `myorg-myaccount.snowflakecomputing.com` |
| **Account locator** (legacy) | `xy12345.us-east-2.aws` | Assigned by Snowflake; may include region and cloud segments |

```sql
SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(),
       CURRENT_ACCOUNT() AS locator, CURRENT_REGION(), CURRENT_VERSION();
```

## 1.5 Connectivity and interfaces

| Interface | What it is | Notes |
|---|---|---|
| **Snowsight** | The browser UI: worksheets, dashboards, Query Profile, cost management, Marketplace | Replaced the Classic Console. Can upload files to stages through the UI. |
| **SnowSQL** | Legacy command-line client | Supports `PUT`/`GET`. Being superseded by Snowflake CLI. |
| **Snowflake CLI** (`snow`) | Newer CLI for SQL, Snowpark, Streamlit, Native Apps | Supports staging files |
| **Drivers** | JDBC, ODBC, Python connector, Node.js, Go, .NET, PHP PDO | Used by BI and ETL tools |
| **Connectors** | Spark connector, Kafka connector, Python connector + pandas, SQLAlchemy | Kafka connector can use Snowpipe or Snowpipe Streaming |
| **SQL API** | REST API for submitting SQL statements | Asynchronous execution supported |
| **Snowpark** | DataFrame API for Python, Java, Scala | Pushes processing down into Snowflake |
| **Partner Connect** | Creates trial accounts with ecosystem partners (ETL, BI, ML) from Snowsight | Requires **ACCOUNTADMIN**; it creates partner-specific objects (database, warehouse, user, role) |
| **Native apps, Streamlit in Snowflake, Notebooks** | Apps and notebooks that run inside Snowflake | Newer topics; the exam may name them |

> **Exam trap:** `PUT` and `GET` **cannot be run from a Snowsight worksheet**. They need a client such as SnowSQL, the Snowflake CLI, or a driver. (Snowsight has its own UI-based file upload, which is a different thing.)

> **Exam trap:** Partner Connect requires the **ACCOUNTADMIN** role and a verified email address.

## 1.6 Other platform features you should recognize

| Feature | One-line summary | Edition |
|---|---|---|
| Snowpark Container Services | Run containerized workloads on Snowflake-managed compute pools | [Standard+] (region availability varies) |
| Cortex AI functions | Built-in LLM and ML SQL functions (for example `COMPLETE`, `SENTIMENT`) | [Standard+] (region availability varies) |
| Hybrid tables (Unistore) | Row-oriented tables for transactional workloads with enforced primary keys | [Standard+]; **not available in trial accounts**; region-limited |
| Iceberg tables | Tables stored in Apache Iceberg format in your own cloud storage | [Standard+] |
| Snowflake Native App Framework | Package and distribute apps through listings | [Standard+] |

## Self-check

**1. Which layer performs query compilation and optimization?**
<details><summary>Answer</summary>The <b>cloud services</b> layer. Virtual warehouses only execute the optimized plan.</details>

**2. When are cloud services credits actually billed?**
<details><summary>Answer</summary>Only for usage above <b>10% of daily virtual warehouse credits</b>, calculated per day in UTC.</details>

**3. Name four features that need at least Enterprise edition.**
<details><summary>Answer</summary>Any four of: multi-cluster warehouses, Time Travel beyond 1 day (up to 90), materialized views, search optimization, query acceleration, masking policies, row access policies, object tagging, access history, periodic rekeying.</details>

**4. What does Business Critical add over Enterprise?**
<details><summary>Answer</summary>Tri-Secret Secure (customer-managed key), private connectivity (PrivateLink and equivalents), support for regulated data (HIPAA/PCI), failover/failback and Client Redirect, and replication of account objects.</details>

**5. Can one Snowflake account span two regions?**
<details><summary>Answer</summary>No. An account lives in a single cloud and region. Multi-region setups use several accounts in one organization, connected with replication.</details>

**6. Which role do you need to use Partner Connect?**
<details><summary>Answer</summary>ACCOUNTADMIN.</details>
