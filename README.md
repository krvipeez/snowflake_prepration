# Snowflake Preparation Pack — SnowPro Core (COF-C02)

A study pack for the **SnowPro Core Certification (COF-C02)**. It is laid out to follow the exam domains, and it also works as a general Snowflake reference.

> **Important — verify against current documentation.**
> Snowflake revises the exam guide (domain weightings, topics, and sometimes the exam code) and changes product defaults, limits, edition availability, and pricing. Some of this happens in its regular behavior-change bundles. This pack shows how things worked when it was written. Before exam day, check any specific number, default, or edition requirement against the official sources:
> - Exam guide and registration: <https://learn.snowflake.com/en/certifications/snowpro-core/>
> - Product documentation: <https://docs.snowflake.com/>
> - Edition feature matrix: <https://docs.snowflake.com/en/user-guide/intro-editions>
>
> If the guide has moved to a newer exam code, the domains below still map closely, but go through the new guide's topic list line by line.

---

## Exam snapshot (COF-C02)

| Item | Detail |
|---|---|
| Exam code | COF-C02 |
| Questions | 100 (may include unscored items) |
| Time limit | 115 minutes |
| Question types | Multiple choice (one answer), multiple select (choose 2 or 3) |
| Passing score | 750 on a scaled 0–1000 range |
| Delivery | Pearson VUE, online-proctored or at a test center |
| Registration fee | USD 175 (lower in some countries such as India) |
| Prerequisites | None formally; around 6 months of hands-on Snowflake use is recommended |
| Validity | 2 years; recertify through the current recertification path or an Advanced exam |
| Pacing | About 69 seconds per question, so flag hard questions and come back to them |

## Domain weightings

| # | Domain | Weight | Approx. questions | Primary chapters |
|---|---|---|---|---|
| 1 | Snowflake AI Data Cloud Features and Architecture | 25% | ~25 | 01, 02, 03, 04 |
| 2 | Account Access and Security | 20% | ~20 | 07, 12 |
| 3 | Performance Concepts | 15% | ~15 | 02, 03, 10 |
| 4 | Data Loading and Unloading | 10% | ~10 | 04, 05 |
| 5 | Data Transformations | 20% | ~20 | 06, 11 |
| 6 | Data Protection and Data Sharing | 10% | ~10 | 08, 09 |

Domains 1, 2 and 5 together are **65%** of the exam, so spend most of your time there.

---

## Index

| File | Topic |
|---|---|
| [01-architecture.md](01-architecture.md) | Three layers, editions matrix, clouds and regions, connectivity |
| [02-virtual-warehouses.md](02-virtual-warehouses.md) | Sizing, scale up vs out, multi-cluster, the four caching layers |
| [03-storage-and-micro-partitions.md](03-storage-and-micro-partitions.md) | Micro-partitions, pruning, clustering keys, search optimization |
| [04-tables-views-and-objects.md](04-tables-views-and-objects.md) | Object model, table types, view types, stages, file formats |
| [05-data-loading-and-unloading.md](05-data-loading-and-unloading.md) | COPY INTO, Snowpipe, PUT/GET, ON_ERROR, validation, unloading |
| [06-semi-structured-data.md](06-semi-structured-data.md) | VARIANT/OBJECT/ARRAY, FLATTEN, MERGE, QUALIFY, unstructured data |
| [07-security-and-access-control.md](07-security-and-access-control.md) | RBAC, system roles, authentication, network policies, encryption, masking |
| [08-data-protection.md](08-data-protection.md) | Time Travel, Fail-safe, zero-copy cloning, replication, failover |
| [09-data-sharing-and-marketplace.md](09-data-sharing-and-marketplace.md) | Shares, reader accounts, listings, Marketplace |
| [10-performance-and-cost.md](10-performance-and-cost.md) | Query Profile, tuning decision tree, credits, resource monitors |
| [11-pipelines-and-programmability.md](11-pipelines-and-programmability.md) | Streams, tasks, dynamic tables, UDFs, procedures, Snowpark |
| [12-governance-and-monitoring.md](12-governance-and-monitoring.md) | ACCOUNT_USAGE vs INFORMATION_SCHEMA, tags, lineage, parameters |
| [13-exam-cheatsheet.md](13-exam-cheatsheet.md) | Condensed revision, one section per exam domain |
| [14-practice-questions.md](14-practice-questions.md) | 60 questions with explained answers and a scoring guide |
| [15-sql-cookbook.sql](15-sql-cookbook.sql) | Runnable end-to-end SQL for a trial account |
| [16-numbers-and-limits.md](16-numbers-and-limits.md) | Every number the exam likes to test, in tables |
| [17-study-plan.md](17-study-plan.md) | Session-by-session plan and readiness checklist |

---

## Conventions used in this pack

### Edition tags

Every feature is tagged with the **minimum** edition that includes it. Higher editions include everything below them.

| Tag | Meaning |
|---|---|
| **[Standard+]** | All editions |
| **[Enterprise+]** | Enterprise, Business Critical, VPS |
| **[Business Critical+]** | Business Critical, VPS |
| **[VPS]** | Virtual Private Snowflake only |

### Callouts

> **Exam trap:** marks a fact that is often missed or a distractor the exam likes to use.

> **Tip:** marks practical advice that is useful beyond the exam.

### Self-checks

Each chapter ends with 5–6 quick questions. The answers are in collapsible `<details>` blocks, so try each one before you expand it.

---

## How to use this pack

1. Follow [17-study-plan.md](17-study-plan.md), which takes about 4 weeks at 1–1.5 hours per session.
2. Read each chapter, then run the matching section of [15-sql-cookbook.sql](15-sql-cookbook.sql) in a free trial account. A trial lets you choose the edition at signup; pick **Enterprise** so you can uncomment the Enterprise-only sections.
3. Do the self-checks at the end of each chapter.
4. In the last week, take [14-practice-questions.md](14-practice-questions.md) under timed conditions and revise with [13-exam-cheatsheet.md](13-exam-cheatsheet.md) and [16-numbers-and-limits.md](16-numbers-and-limits.md).

## Official resources worth using alongside this pack

- SnowPro Core exam guide (PDF, linked from the certification page)
- Snowflake documentation: <https://docs.snowflake.com/>
- Hands-on Essentials badges and quickstarts: <https://quickstarts.snowflake.com/>
- Snowflake free trial (30 days): <https://signup.snowflake.com/>
