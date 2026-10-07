# 17 — Study Plan and Readiness Checklist

A **16-session plan** of about 60–90 minutes per session. At 4 sessions a week it takes about **4 weeks**. If you already use Snowflake daily, you can compress it to 2 weeks by doubling up the sessions in weeks 1–3.

**Before session 1:** sign up for a 30-day trial at <https://signup.snowflake.com/> and choose **Enterprise** edition, so the Enterprise-only parts of the cookbook will work. Pick the cloud and region you're most likely to use at work.

Each session follows the same pattern:

1. **Read** the chapter (30–40 min).
2. **Do** the listed cookbook sections in [15-sql-cookbook.sql](15-sql-cookbook.sql) (20–30 min).
3. **Check yourself** with the chapter's self-check questions (5–10 min). Write down every miss.

---

## Week 1 — Architecture and compute (Domain 1, 25%)

| # | Topic | Read | Cookbook | Outcome |
|---|---|---|---|---|
| 1 | Platform, layers, editions | [01](01-architecture.md) | §00, §01 | You can draw the three layers and recite the Enterprise and Business Critical feature lists |
| 2 | Virtual warehouses and caching | [02](02-virtual-warehouses.md) | §02, §23 (cache part) | You can explain scale up vs scale out, both scaling policies, and all four cache layers |
| 3 | Micro-partitions and clustering | [03](03-storage-and-micro-partitions.md) | §23 (clustering and pruning part) | You can read `SYSTEM$CLUSTERING_INFORMATION` output and know when clustering is worth it |
| 4 | Objects, table types, views, stages | [04](04-tables-views-and-objects.md) | §03, §05, §14 | You can fill in the table-type comparison and the stage comparison from memory |

**End of week 1:** answer practice questions **Q1–Q15** (untimed).

## Week 2 — Loading and transformations (Domains 4 and 5, 30%)

| # | Topic | Read | Cookbook | Outcome |
|---|---|---|---|---|
| 5 | Bulk loading and validation | [05](05-data-loading-and-unloading.md) §5.1–5.4 | §06–§09 | You know the ON_ERROR defaults, the 64-day metadata rule, and all three VALIDATION_MODE values |
| 6 | Snowpipe, schema inference, unloading | [05](05-data-loading-and-unloading.md) §5.5–5.9 | §10, §11 | You can fill in the bulk COPY vs Snowpipe comparison and know the unload options |
| 7 | Semi-structured data and SQL transformations | [06](06-semi-structured-data.md) | §12, §13, §27 | You can write a LATERAL FLATTEN, a QUALIFY, and a MERGE without notes |
| 8 | Streams, tasks, dynamic tables, UDFs, procedures | [11](11-pipelines-and-programmability.md) | §20, §21, §22 | You can explain stream offsets, task privileges, and when to use a UDF vs a procedure |

**End of week 2:** answer practice questions **Q37–Q54** (untimed).

## Week 3 — Security, performance, protection, sharing (Domains 2, 3, 6, 45%)

| # | Topic | Read | Cookbook | Outcome |
|---|---|---|---|---|
| 9 | RBAC and system roles | [07](07-security-and-access-control.md) §7.1–7.3 | §17 | You can draw the role hierarchy and say which role does what |
| 10 | Authentication, network policies, encryption, masking, row access | [07](07-security-and-access-control.md) §7.4–7.7 | §18, §19 | You can recite network policy precedence, the key hierarchy, and the order policies are evaluated in |
| 11 | Performance tuning and cost | [10](10-performance-and-cost.md) | §23, §24, §25 | You can walk the tuning decision tree, and know every resource monitor rule |
| 12 | Time Travel, Fail-safe, cloning, replication | [08](08-data-protection.md) | §15, §16, §29 (read only) | You know every retention number and the cloning rules |
| 13 | Sharing, Marketplace, governance | [09](09-data-sharing-and-marketplace.md), [12](12-governance-and-monitoring.md) | §26, §28 | You can fill in the ACCOUNT_USAGE vs INFORMATION_SCHEMA comparison and the consumer restrictions |

**End of week 3:** answer practice questions **Q16–Q36** and **Q55–Q60** (untimed).

## Week 4 — Consolidation and exam simulation

| # | Activity | Detail |
|---|---|---|
| 14 | **Full timed mock** | All 60 questions in [14](14-practice-questions.md) in **70 minutes**, closed book. Score by domain with the scoring guide. |
| 15 | **Gap repair** | Re-read the "Exam trap" notes and self-checks for your **two weakest domains**. Rerun the matching cookbook sections. Memorize [16](16-numbers-and-limits.md). |
| 16 | **Final review** (the day before the exam) | Read [13-exam-cheatsheet.md](13-exam-cheatsheet.md) twice. Check exam logistics. Stop studying by evening. |

> **Tip:** Questions in this pack will start to feel familiar by week 4. To test yourself on fresh wording, also take the official practice exam from Snowflake, if one is available for your exam version.

---

## Exam-day tactics

- **Pace:** about 69 seconds per question. Flag anything that takes longer than 90 seconds and move on.
- **Multi-select:** the question tells you how many answers to choose. There's no partial credit, so check each option on its own as true or false.
- **Edition keywords:** if a question mentions an edition, the answer usually depends on a feature boundary (Enterprise vs Business Critical).
- **"Best" or "most cost-effective":** prefer serverless or automatic features and the smallest change that solves the stated problem.
- **Absolute words** such as "always", "never", or "only" are usually traps, except for known absolutes like "Fail-safe is only recoverable by Snowflake Support".
- **Online proctoring:** clear your desk, use one monitor, close all other apps, and have photo ID ready. Run the system test the day before.

---

## Readiness checklist

Tick every box before you book, or at least a week before your exam date.

### Architecture and editions
- [ ] I can describe the 3 layers and what each one does, including where the optimizer runs.
- [ ] I can list the Enterprise+ and Business Critical+ features from memory.
- [ ] I can explain the 10% cloud services billing rule with an example.
- [ ] I know the warehouse credit ladder (XS = 1 through 6XL = 512), and the 60-second minimum.

### Warehouses and performance
- [ ] I can say when to scale up vs scale out, and the difference between Standard and Economy scaling.
- [ ] I can name the result cache conditions, and its 24-hour / 31-day lifetime.
- [ ] I can read a Query Profile for spilling, pruning, exploding joins, and queuing.
- [ ] I know when to use clustering, search optimization, MVs, and QAS, and their editions.
- [ ] I know every resource monitor rule (who creates them, scope, actions, what they don't cover).

### Storage and objects
- [ ] I can describe micro-partitions (size, immutability, metadata) and know which constraints are enforced.
- [ ] I know Time Travel and Fail-safe per table type and edition.
- [ ] I can tell the 4 stage types apart, and know which ones support transformations.
- [ ] I know the differences between secure views and materialized views, and MV limitations.

### Loading and unloading
- [ ] I know the ON_ERROR defaults (COPY vs Snowpipe) and all of the options.
- [ ] I know load metadata retention (64 vs 14 days), plus FORCE and LOAD_UNCERTAIN_FILES.
- [ ] I know the PUT/GET rules (internal only, client only).
- [ ] I know the unload rules (formats, SINGLE, MAX_FILE_SIZE 16 MB / 5 GB, JSON single column).

### Transformations
- [ ] I can write FLATTEN with OUTER and RECURSIVE, and name all 6 output columns.
- [ ] I know path case-sensitivity, casting, and JSON null vs SQL NULL.
- [ ] I know stream types, metadata columns, consumption, and staleness.
- [ ] I know the task lifecycle and privileges (EXECUTE TASK, EXECUTE MANAGED TASK) and graph rules.
- [ ] I can compare dynamic tables, MVs, and streams + tasks.
- [ ] I know UDF vs procedure, owner's vs caller's rights, and the three unstructured URL types.

### Security
- [ ] I can draw the system role hierarchy and give each role's purpose.
- [ ] I know future grants, managed access schemas, and secondary roles.
- [ ] I know the authentication methods, including that SCIM is provisioning and key-pair supports rotation.
- [ ] I know network policy precedence and where policies can be applied.
- [ ] I know the encryption key hierarchy, rotation vs rekeying, and Tri-Secret Secure.
- [ ] I know masking and row access policies (edition, one per column or table, evaluation order).

### Protection and sharing
- [ ] I know cloning rules (grants, load metadata, stages, pipes, tasks, transient → permanent).
- [ ] I know which replication features are Standard and which are Business Critical.
- [ ] I know what consumers can and can't do with shares, and the reader account billing.
- [ ] I know how to share across regions (replication or auto-fulfillment).

### Governance
- [ ] I know ACCOUNT_USAGE vs INFORMATION_SCHEMA (latency, retention, dropped objects, access).
- [ ] I know tags (Enterprise+, 50 per object, inheritance), access history, and classification.
- [ ] I know the parameter hierarchy and the "lower timeout wins" rule.

### Mock results
- [ ] Full timed mock score ≥ **80%** (48/60).
- [ ] Every domain at or above its target in the scoring guide.
- [ ] I have reviewed every missed question and can explain why each wrong option is wrong.

When every box is ticked, you're ready. Before you sit the exam, check the current official exam guide for topic changes, as noted in the [README](README.md).
