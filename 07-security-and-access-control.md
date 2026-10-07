# 07 — Security and Access Control

**Exam domain:** 2 (Account Access and Security, 20%)

## 7.1 Access control models

Snowflake combines two models:

| Model | Meaning in Snowflake |
|---|---|
| **Discretionary Access Control (DAC)** | Every object has an **owner**: the role with the `OWNERSHIP` privilege. The owner can grant access to the object. |
| **Role-Based Access Control (RBAC)** | Privileges are granted to **roles**, and roles are granted to **users** or to other roles. Users never receive privileges directly. |

Key concepts:

- **Securable object**: anything privileges can be granted on (warehouse, database, table, and so on).
- **Privilege**: a defined level of access, such as `SELECT`, `USAGE`, `OWNERSHIP`, or `MONITOR`.
- **Role**: the entity that holds privileges.
- **User**: an identity (person or service) that is granted roles.
- **Role hierarchy**: granting role A to role B means **B inherits all of A's privileges**. Privileges flow **upward**.

> **Exam trap:** Privileges are **never** granted directly to users in standard RBAC. They're granted to roles, and roles are granted to users.

> **Exam trap:** Objects are owned by **roles, not users**. When the creating user leaves, the object is still owned by the role.

## 7.2 System-defined roles

```
              ORGADMIN   (organization level, separate)
                  
              ACCOUNTADMIN
              /          \
      SECURITYADMIN     SYSADMIN
            |               |
        USERADMIN      custom roles  (best practice: grant to SYSADMIN)
            \               /
                 PUBLIC   (granted to every user and role automatically)
```

| Role | Purpose | Key privileges |
|---|---|---|
| **ORGADMIN** | Manages the organization: creates accounts, views organization usage, enables replication. Newer organization accounts may use a global organization admin role, so check the docs. | `CREATE ACCOUNT`, organization usage views |
| **ACCOUNTADMIN** | Top-level account role. Contains SYSADMIN and SECURITYADMIN. | Billing, resource monitors, shares, account parameters, `ACCOUNT_USAGE` access, Partner Connect |
| **SECURITYADMIN** | Manages **grants** globally. Contains USERADMIN. | **`MANAGE GRANTS`**, plus everything USERADMIN has; creates network policies |
| **USERADMIN** | User and role management | **`CREATE USER`**, **`CREATE ROLE`** |
| **SYSADMIN** | Creates and owns **warehouses, databases**, and other objects | `CREATE WAREHOUSE`, `CREATE DATABASE` |
| **PUBLIC** | Pseudo-role every user and role has | Whatever is granted to PUBLIC |

Best practices:

- Grant **custom roles to SYSADMIN**, so SYSADMIN (and ACCOUNTADMIN) can manage the objects those roles create.
- Limit **ACCOUNTADMIN** to a small number of users, but **at least two**. Require **MFA** for them, and **don't make it anyone's default role**.
- Don't use ACCOUNTADMIN to create objects. Use SYSADMIN or custom roles.

> **Exam trap:** The **lowest** system role that can create users and roles is **USERADMIN**. The role that can grant **any** privilege on any object, without owning it, is **SECURITYADMIN**, through `MANAGE GRANTS`.

> **Exam trap:** If a custom role isn't granted to SYSADMIN, objects it owns are **invisible to SYSADMIN**. This is an "orphaned" role hierarchy.

### Other role types

| Role type | Scope | Use |
|---|---|---|
| **Account role** | Account | Normal RBAC |
| **Database role** | A single database | Bundle privileges inside a database. Can be **granted to shares**. Must be granted to an account role (or another database role in the same database) before users can use it. |
| **Application role** | Native app | Access control inside a Native App |
| **Instance role** | An instance of a Snowflake class (for example a budget or an ML forecast model) | Fine-grained access to that instance |

## 7.3 Privileges you must know

| Object | Privileges |
|---|---|
| Warehouse | `USAGE` (run queries), `OPERATE` (start, suspend, resume, **cancel queries**), `MODIFY` (resize, change properties), `MONITOR` (view usage and queries), `OWNERSHIP` |
| Database / schema | `USAGE` (required to access **any** object inside), `CREATE SCHEMA` / `CREATE TABLE` / ..., `MONITOR`, `OWNERSHIP` |
| Table | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `OWNERSHIP` |
| Account | `CREATE DATABASE`, `CREATE WAREHOUSE`, `CREATE ROLE`, `CREATE USER`, `MANAGE GRANTS`, `EXECUTE TASK`, `EXECUTE MANAGED TASK`, `IMPORT SHARE`, `CREATE SHARE`, `MONITOR USAGE`, `APPLY MASKING POLICY`, ... |

To query a table, a role needs **`USAGE` on the warehouse, `USAGE` on the database, `USAGE` on the schema, and `SELECT` on the table**.

```sql
USE ROLE USERADMIN;
CREATE ROLE analyst;
GRANT ROLE analyst TO ROLE SYSADMIN;
GRANT ROLE analyst TO USER jdoe;

USE ROLE SECURITYADMIN;
GRANT USAGE ON WAREHOUSE bi_wh TO ROLE analyst;
GRANT USAGE ON DATABASE sales TO ROLE analyst;
GRANT USAGE ON SCHEMA sales.core TO ROLE analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA sales.core TO ROLE analyst;      -- existing tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA sales.core TO ROLE analyst;   -- tables created later

SHOW GRANTS TO ROLE analyst;    -- what the role has
SHOW GRANTS OF ROLE analyst;    -- who has the role
SHOW GRANTS ON TABLE sales.core.orders;
SHOW FUTURE GRANTS IN SCHEMA sales.core;
```

> **Exam trap:** `GRANT ... ON ALL TABLES` covers **only existing tables**. Tables created later need **`ON FUTURE TABLES`**. When future grants exist at both database and schema level, the **schema-level** future grants win for that schema.

> **Exam trap:** Transferring ownership with `GRANT OWNERSHIP ... COPY CURRENT GRANTS` keeps the existing grants. With `REVOKE CURRENT GRANTS`, they're removed.

### Managed access schemas

```sql
CREATE SCHEMA secure_core WITH MANAGED ACCESS;
```

In a **managed access schema**, object owners **can't** grant privileges on their objects. Only the **schema owner**, or a role with **`MANAGE GRANTS`**, can grant them. This centralizes grant control. [Standard+]

### Primary and secondary roles

- The **primary role** (`USE ROLE x`) owns the objects you create, and is used for `CREATE` authorization.
- **Secondary roles** (`USE SECONDARY ROLES ALL`) add their privileges for **queries and DML**. Newer accounts may enable all secondary roles by default, so check `DEFAULT_SECONDARY_ROLES`.
- A user's **default role** is set with `ALTER USER ... SET DEFAULT_ROLE`.

## 7.4 Authentication

| Method | Notes | Edition |
|---|---|---|
| **Username + password** | Password policies (length, complexity, age). Snowflake is phasing out single-factor password sign-in for human users, so check the current MFA enforcement timeline. | [Standard+] |
| **MFA** | Duo-based push, passcode, or other factors; enrolled per user. **MFA token caching** cuts repeated prompts for drivers. | [Standard+] |
| **Federated auth / SSO** | **SAML 2.0** identity provider (Okta, Microsoft Entra ID/ADFS, and others). Configured with a SAML2 security integration. | [Standard+] |
| **OAuth** | **Snowflake OAuth** (Snowflake is the authorization server) or **External OAuth** (Okta, Entra ID, PingFederate, and others) | [Standard+] |
| **Key-pair** | RSA key pair, **minimum 2048-bit**. Public key set on the user with `RSA_PUBLIC_KEY`. A second slot, `RSA_PUBLIC_KEY_2`, allows **rotation**. Standard for service accounts and the Snowpipe REST API. | [Standard+] |
| **Programmatic access tokens / workload identity federation** | Newer methods for services and automation | [Standard+] |
| **SCIM** | **Automates user and group provisioning** from the IdP (Okta, Entra ID). It is **not** an authentication method. | [Standard+] |

```sql
ALTER USER svc_etl SET RSA_PUBLIC_KEY = 'MIIBIjANBgkq...';
ALTER USER svc_etl SET TYPE = SERVICE;        -- service users can't use passwords/MFA prompts
```

> **Exam trap:** **SCIM** does **provisioning**, not sign-in. **SAML** is for **SSO**.

> **Exam trap:** Key-pair authentication supports **two active public keys** per user, which allows rotation without downtime.

### Session and authentication policies

- **Session policy**: idle timeout for UI and client sessions (`SESSION_IDLE_TIMEOUT_MINS`, with a default of 240 minutes, or 4 hours).
- **Authentication policy**: restricts which methods, clients, and security integrations a user or account may use.
- **Password policy**: complexity and expiry rules.

## 7.5 Network security

### Network policies [Standard+]

```sql
CREATE NETWORK POLICY corp_only
  ALLOWED_IP_LIST = ('203.0.113.0/24')
  BLOCKED_IP_LIST = ('203.0.113.99');

ALTER ACCOUNT SET NETWORK_POLICY = corp_only;     -- account level
ALTER USER jdoe SET NETWORK_POLICY = corp_only;   -- user level
```

| Rule | Detail |
|---|---|
| Where they can be applied | **Account**, **user**, or **security integration** (for example OAuth) |
| Precedence | **Most specific wins**: a user-level policy **overrides** the account-level one |
| Blocked vs allowed | `BLOCKED_IP_LIST` takes priority over `ALLOWED_IP_LIST` |
| Number active | **One** policy per account and **one** per user at a time |
| Who can create | **SECURITYADMIN** or higher, or a role with `CREATE NETWORK POLICY` |
| Network rules | Newer model: schema-level **network rules** (IPv4, VPC endpoint IDs, hosts) referenced via `ALLOWED_NETWORK_RULE_LIST` / `BLOCKED_NETWORK_RULE_LIST` |

> **Exam trap:** You **can't activate** an account network policy that would **block your own current IP**. Snowflake checks for this.

### Private connectivity [Business Critical+]

AWS PrivateLink, Azure Private Link, and Google Private Service Connect keep traffic off the public internet, both to Snowflake and to internal stages.

## 7.6 Encryption

| Aspect | Detail | Edition |
|---|---|---|
| At rest | **AES-256**, always on, can't be disabled | [Standard+] |
| In transit | **TLS 1.2+** for all client connections | [Standard+] |
| Key model | **Hierarchical**: root key (in a cloud HSM) → **account master key** → **table master key** → **file keys** | [Standard+] |
| Key rotation | Active keys are retired every **30 days**. Retired keys are only used for decryption. | [Standard+] |
| **Periodic rekeying** | Data encrypted with keys **older than 1 year** is re-encrypted with new keys (`PERIODIC_DATA_REKEYING = TRUE`) | **[Enterprise+]** |
| **Tri-Secret Secure** | Composite master key = Snowflake-managed key + **customer-managed key** in the cloud KMS. Revoking the customer key makes the data unreadable. | **[Business Critical+]** |
| Client-side encryption for external stages | Supply a `MASTER_KEY` so Snowflake can read files you encrypted | [Standard+] |

> **Exam trap:** **Key rotation** (every 30 days, all editions) is **not** the same as **periodic rekeying** (annual re-encryption of old data, [Enterprise+]).

## 7.7 Column-level and row-level security

### Dynamic data masking [Enterprise+]

A **masking policy** is a schema-level object that rewrites a column's value **at query time**, based on context such as the current role.

```sql
CREATE MASKING POLICY mask_email AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_READER') THEN val
       ELSE REGEXP_REPLACE(val, '.+@', '*****@') END;

ALTER TABLE customers MODIFY COLUMN email SET MASKING POLICY mask_email;
ALTER TABLE customers MODIFY COLUMN email UNSET MASKING POLICY;
```

- The input and output data types must match.
- A column can have **only one masking policy**.
- **Conditional masking** passes extra columns as arguments: `(val STRING, consent BOOLEAN)`.
- **Tag-based masking**: attach a policy to a **tag**, and every column with that tag is masked [Enterprise+].
- **External tokenization**: the policy calls an **external function** to detokenize [Enterprise+].
- Context functions: `CURRENT_ROLE()`, `IS_ROLE_IN_SESSION()`, `INVOKER_ROLE()`, `CURRENT_USER()`, `CURRENT_ACCOUNT()`.

### Row access policies [Enterprise+]

```sql
CREATE ROW ACCESS POLICY rap_region AS (region STRING) RETURNS BOOLEAN ->
  IS_ROLE_IN_SESSION('GLOBAL_SALES')
  OR EXISTS (SELECT 1 FROM sec.region_map m
             WHERE m.role_name = CURRENT_ROLE() AND m.region = region);

ALTER TABLE sales ADD ROW ACCESS POLICY rap_region ON (region);
```

- It returns a BOOLEAN; rows where it's FALSE are filtered out.
- A table or view can have **only one row access policy**.
- Mapping tables are a common pattern.

> **Exam trap:** When a table has both, the **row access policy is evaluated first**, then the masking policies.

> **Exam trap:** Masking and row access policies apply **everywhere the table is queried**: views, shares, and clones. A policy that refers to `CURRENT_ROLE()` may behave differently in a consumer account, so use `IS_DATABASE_ROLE_IN_SESSION()` or account checks for shares.

### Other policies [Enterprise+]

| Policy | Purpose |
|---|---|
| **Aggregation policy** | Forces queries to aggregate over groups of at least N rows (privacy) |
| **Projection policy** | Prevents a column from appearing in SELECT output, while still allowing it in filters and joins |
| **Join policy** | Requires joins on specified columns |

### Secure views and secure UDFs [Standard+]

- Their definition is hidden from non-owners.
- Optimizations that could expose underlying data are disabled.
- They're required for sharing views and UDFs.
- They're a common way to implement row- and column-level security in **Standard edition**, where policies aren't available.

### Comparison: ways to restrict data

| Need | Standard | Enterprise+ |
|---|---|---|
| Hide some columns | Secure view selecting only allowed columns | Masking policy, projection policy |
| Mask values per role | Secure view with `CASE CURRENT_ROLE()` | **Masking policy** (centralized, follows the column) |
| Filter rows per role | Secure view with `WHERE` against a mapping table | **Row access policy** |
| Tag-driven governance | | Object tagging + tag-based masking |

## Self-check

**1. Which system role holds MANAGE GRANTS by default?**
<details><summary>Answer</summary><b>SECURITYADMIN</b>. ACCOUNTADMIN inherits it.</details>

**2. A user-level and an account-level network policy both exist. Which applies to that user?**
<details><summary>Answer</summary>The <b>user-level</b> policy. The most specific one wins.</details>

**3. What does SCIM do?**
<details><summary>Answer</summary>It automates <b>user and role provisioning</b> from an identity provider. It is not used to sign in.</details>

**4. Which edition is needed for masking policies, and for Tri-Secret Secure?**
<details><summary>Answer</summary>Masking policies: <b>Enterprise+</b>. Tri-Secret Secure: <b>Business Critical+</b>.</details>

**5. In a managed access schema, who can grant privileges on a table?**
<details><summary>Answer</summary>The <b>schema owner</b>, or a role with <b>MANAGE GRANTS</b>. The table owner can't.</details>

**6. Which is evaluated first, a row access policy or a masking policy?**
<details><summary>Answer</summary>The <b>row access policy</b>.</details>
