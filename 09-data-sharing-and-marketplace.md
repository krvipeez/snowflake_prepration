# 09 — Data Sharing and Marketplace

**Exam domain:** 6 (Data Protection and Data Sharing, 10%)

## 9.1 Secure Data Sharing [Standard+]

Secure Data Sharing lets a **provider** account give **consumer** accounts **live, read-only access** to selected objects, with **no data copied or moved**. The consumer queries the provider's micro-partitions directly, through cloud services metadata.

| | Provider | Consumer |
|---|---|---|
| Pays for storage | **Yes** (the data stays in the provider account) | No |
| Pays for compute | Only for its own queries | **Yes**, its own warehouses (except reader accounts) |
| Sees changes | | **Immediately**; the data is live |
| Can modify the data | Yes | **No**; read-only |

### What can be shared

| Shareable | Not directly shareable |
|---|---|
| Databases, schemas (through `USAGE`) | **Standard (non-secure) views** |
| Tables, external tables, dynamic tables, Iceberg tables | Standard UDFs |
| **Secure views**, **secure materialized views** | Stages, pipes, tasks, streams (streams on shared objects can be created by the consumer, if allowed) |
| **Secure UDFs** | Warehouses, users, roles |
| **Database roles** (to give consumers fine-grained access) | |

### Provider workflow

```sql
USE ROLE ACCOUNTADMIN;                 -- or a role with CREATE SHARE
CREATE SHARE sales_share;
GRANT USAGE ON DATABASE sales TO SHARE sales_share;
GRANT USAGE ON SCHEMA sales.core TO SHARE sales_share;
GRANT SELECT ON TABLE sales.core.orders TO SHARE sales_share;
GRANT SELECT ON VIEW  sales.core.v_region_secure TO SHARE sales_share;   -- must be SECURE
ALTER SHARE sales_share ADD ACCOUNTS = myorg.partner_acct;
SHOW SHARES;  DESC SHARE sales_share;

-- objects from another database inside a secure view:
GRANT REFERENCE_USAGE ON DATABASE ref_db TO SHARE sales_share;
```

### Consumer workflow

```sql
USE ROLE ACCOUNTADMIN;                 -- or a role with IMPORT SHARE + CREATE DATABASE
SHOW SHARES;                           -- INBOUND shares listed
CREATE DATABASE partner_sales FROM SHARE provider_org.provider_acct.sales_share;
GRANT IMPORTED PRIVILEGES ON DATABASE partner_sales TO ROLE analyst;
```

### Restrictions on a database created from a share

| Restriction | Detail |
|---|---|
| Read-only | No DML or DDL on the shared objects |
| **No cloning** | Consumers can't clone a shared database or its objects |
| **No Time Travel** | Consumers can't query shared data with `AT` or `BEFORE` |
| **No re-sharing** | Consumers can't add shared objects to their own shares |
| One database per share | Each share is mounted as **one** database in the consumer account |
| Privileges | Granted to consumer roles with `IMPORTED PRIVILEGES` (all-or-nothing) or with **database roles** shared by the provider (fine-grained) |

> **Exam trap:** A consumer **can** join shared data with its own data, create views on it in its own databases, and copy it into its own tables with CTAS.

> **Exam trap:** A share can't directly grant a **non-secure view**; the grant fails. Make the view **SECURE**.

> **Exam trap:** Shares created by a **Business Critical** provider can't be consumed by a lower-edition account unless the provider sets `SHARE_RESTRICTIONS = FALSE`, which needs the `OVERRIDE SHARE RESTRICTIONS` privilege.

### Same region vs cross-region

| Situation | How |
|---|---|
| Consumer in the **same region and cloud** | Direct share |
| Consumer in a **different region or cloud** | **Replicate** the database (or a replication group with the share) to an account in the consumer's region and share from there, **or** use a **listing with Cross-Cloud Auto-Fulfillment** |

> **Exam trap:** Direct shares only work **within one region**. Cross-region sharing always involves replication, whether you set it up yourself or auto-fulfillment does it.

## 9.2 Reader accounts [Standard+]

A **reader account** (a managed account) is created **by a provider** for a consumer that **doesn't have its own Snowflake account**.

```sql
CREATE MANAGED ACCOUNT partner_reader
  ADMIN_NAME = 'reader_admin', ADMIN_PASSWORD = 'Str0ng!Passw0rd', TYPE = READER;
SHOW MANAGED ACCOUNTS;
ALTER SHARE sales_share ADD ACCOUNTS = <reader_account_locator>;
```

| Property | Detail |
|---|---|
| Who pays compute | **The provider**. Warehouses created in the reader account are billed to the provider. |
| What it can consume | Shares **from its parent provider only** |
| DML / data loading | **No**: it can't load data or run INSERT/UPDATE/DELETE on shared data |
| Can it share? | No |
| Cost control | Providers should put **resource monitors** on reader-account warehouses |
| Limit | A default limit on reader accounts per provider (commonly cited as 20; it can be raised through support) |

> **Exam trap:** In reader accounts, **the provider pays for the compute**. With a full consumer account, the consumer pays.

## 9.3 Listings and Snowflake Marketplace

A **listing** wraps a share (or a Native App) with metadata: title, description, sample queries, terms, and pricing.

| Listing type | Audience | Notes |
|---|---|---|
| **Private listing** | Specific accounts you choose | Replaces most uses of the legacy "Data Exchange" |
| **Public listing (Snowflake Marketplace)** | Any Snowflake customer | Discovery through Marketplace in Snowsight |

| Marketplace offering | Meaning |
|---|---|
| **Free** | Immediate access to the shared data |
| **Limited trial** | Time- or feature-limited access before paying |
| **Paid** | Billed by Snowflake on the provider's behalf (usage-based or subscription) |
| **Personalized** (request-based) | The consumer requests access, and the provider fulfills it with customer-specific data |

Facts to know:

- **Cross-Cloud Auto-Fulfillment** replicates listing data to other regions automatically when consumers there request it. The provider pays the replication costs.
- **Provider profiles** represent the publishing organization.
- Consuming a Marketplace listing creates a **database from the share** in the consumer account, with the same restrictions as a direct share.
- **Native Apps** (Snowflake Native App Framework) are distributed through listings and can include code as well as data.
- **Data Clean Rooms** allow privacy-preserving joint analysis between parties.

## 9.4 Sharing options compared

| Option | Consumer needs a Snowflake account? | Cross-region? | Who pays compute | Discovery |
|---|---|---|---|---|
| Direct share | Yes | No (same region only) | Consumer | Manual (`ALTER SHARE ADD ACCOUNTS`) |
| Reader account | **No** (the provider creates one) | No | **Provider** | Manual |
| Private listing | Yes | Yes (auto-fulfillment) | Consumer | Invited accounts |
| Marketplace listing | Yes | Yes (auto-fulfillment) | Consumer | Public catalog |
| Replication + share | Yes | Yes | Consumer (the provider pays replication) | Manual |

## Self-check

**1. Who pays storage for shared data?**
<details><summary>Answer</summary>The <b>provider</b>. Consumers pay nothing for storage.</details>

**2. Name three things a consumer cannot do with a database created from a share.**
<details><summary>Answer</summary>Modify it (DML/DDL), clone it, use Time Travel on it, or re-share it.</details>

**3. What must be true of a view before it can be added to a share?**
<details><summary>Answer</summary>It must be a <b>secure</b> view.</details>

**4. Who pays for queries run in a reader account?**
<details><summary>Answer</summary>The <b>provider</b> that created the reader account.</details>

**5. How do you share with a consumer in a different cloud region?**
<details><summary>Answer</summary>Replicate the data to an account in that region and share from there, or publish a listing with Cross-Cloud Auto-Fulfillment.</details>

**6. Which privilege lets roles in the consumer account query a shared database?**
<details><summary>Answer</summary><code>GRANT IMPORTED PRIVILEGES ON DATABASE ... TO ROLE ...</code>, or grants of database roles the provider included in the share.</details>
