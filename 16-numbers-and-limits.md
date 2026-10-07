# 16 — Numbers and Limits

Every number the SnowPro Core exam likes to test, grouped by topic. Values marked † change most often between releases, so check them in the docs before the exam.

## Exam

| Item | Value |
|---|---|
| Questions | 100 |
| Time | 115 minutes |
| Passing score | 750 / 1000 (scaled) |
| Fee | USD 175 |
| Validity | 2 years |
| Domain weights | 25 / 20 / 15 / 10 / 20 / 10 % |

## Architecture and billing

| Item | Value |
|---|---|
| Architecture layers | 3 (storage, compute, cloud services) |
| Supported clouds | 3 (AWS, Azure, GCP) |
| Editions | 4 (Standard, Enterprise, Business Critical, VPS) |
| Cloud services free allowance | **10%** of daily warehouse credits |
| Billing granularity | Per **second** |
| Minimum billing on each start or resume | **60 seconds** |
| Storage billing basis | Average compressed TB per month |

## Warehouses

| Size | XS | S | M | L | XL | 2XL | 3XL | 4XL | 5XL | 6XL |
|---|---|---|---|---|---|---|---|---|---|---|
| Credits / hour | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512 |

| Parameter / limit | Value |
|---|---|
| `AUTO_SUSPEND` default | **600 s** (10 min) |
| `AUTO_RESUME` default | TRUE |
| `MAX_CLUSTER_COUNT` (classic exam figure) | **10** † |
| `MIN_CLUSTER_COUNT` default | 1 |
| Standard policy: delay between starting successive clusters | **20 s** |
| Standard policy: shutdown checks | **2–3** consecutive checks, 1 minute apart |
| Economy policy: work needed to start a cluster | **6 minutes** of estimated load |
| Economy policy: shutdown checks | **5–6** consecutive checks |
| `MAX_CONCURRENCY_LEVEL` default | **8** |
| `STATEMENT_TIMEOUT_IN_SECONDS` default | **172,800** (2 days) |
| `STATEMENT_QUEUED_TIMEOUT_IN_SECONDS` default | 0 (no limit) |
| Snowpark-optimized memory per node | ~**16x** standard |
| `QUERY_ACCELERATION_MAX_SCALE_FACTOR` default | **8** (0 = no limit) |

## Caching

| Item | Value |
|---|---|
| Result cache retention | **24 hours** |
| Result cache maximum (with repeated reuse) | **31 days** |
| Warehouse cache lifetime | Until the warehouse suspends |

## Storage and micro-partitions

| Item | Value |
|---|---|
| Micro-partition size (uncompressed) | **50–500 MB** |
| Recommended max clustering key columns | **3–4** |
| Typical table size where clustering pays off | Multi-**TB** |
| Max identifier length | **255** characters |
| VARCHAR / VARIANT max size (classic) | **16 MB** (16,777,216 bytes) † |
| BINARY max size (classic) | **8 MB** † |
| `NUMBER` default precision / scale | 38 / 0 |

## Time Travel and Fail-safe

| Item | Standard | Enterprise+ |
|---|---|---|
| Default `DATA_RETENTION_TIME_IN_DAYS` | 1 | 1 |
| Max Time Travel, permanent | **1** | **90** |
| Max Time Travel, transient and temporary | 1 | 1 |
| Fail-safe, permanent | **7** | **7** |
| Fail-safe, transient and temporary | 0 | 0 |
| Max total recovery window, permanent | 8 days | **97 days** |

| Parameter | Default |
|---|---|
| `MAX_DATA_EXTENSION_TIME_IN_DAYS` (stream staleness protection) | **14** days |
| `MIN_DATA_RETENTION_TIME_IN_DAYS` (account level) | 0 |
| `AT(OFFSET => n)` unit | **seconds** |

## Loading and unloading

| Item | Value |
|---|---|
| Recommended load file size | **100–250 MB compressed** |
| Bulk COPY load metadata retention | **64 days** |
| Snowpipe load history retention | **14 days** |
| `ALTER PIPE ... REFRESH` look-back | **7 days** |
| `FILES = (...)` max list | **1,000** files |
| `VALIDATE()` look-back | 14 days |
| Recommended Snowpipe staging frequency | About once per **minute** |
| Unload `MAX_FILE_SIZE` default | **16 MB** |
| Unload `MAX_FILE_SIZE` maximum (cloud storage) | **5 GB** |
| `PUT` default `PARALLEL` | **4** threads |
| `PUT` default compression | gzip (`AUTO_COMPRESS = TRUE`) |
| Load formats | 6: CSV, JSON, Avro, ORC, Parquet, XML |
| Unload formats | 3: CSV, JSON, Parquet |
| Snowpipe per-file overhead (legacy pricing) | 0.06 credits per 1,000 files † |

## Security

| Item | Value |
|---|---|
| Encryption at rest | **AES-256** |
| TLS for data in transit | **1.2+** |
| Key rotation (active keys retired) | Every **30 days** |
| Periodic rekeying [Enterprise+] | Keys older than **1 year** |
| Key-pair minimum key size | **2048-bit** RSA |
| Public keys per user | **2** (`RSA_PUBLIC_KEY`, `RSA_PUBLIC_KEY_2`) |
| Network policies active per account or user | **1** each |
| Session idle timeout default | **4 hours** (240 min) |
| Minimum ACCOUNTADMIN users (best practice) | **2** |
| Masking policies per column | **1** |
| Row access policies per table or view | **1** |

## Governance and monitoring

| Item | Value |
|---|---|
| ACCOUNT_USAGE retention | **365 days** |
| ACCOUNT_USAGE latency | **45 min to 3 h** (view-dependent) |
| `ACCOUNT_USAGE.QUERY_HISTORY` latency | ~45 min |
| `ACCOUNT_USAGE.ACCESS_HISTORY` latency | up to 3 h |
| `INFORMATION_SCHEMA.QUERY_HISTORY()` look-back | **7 days** |
| `INFORMATION_SCHEMA.LOGIN_HISTORY()` look-back | 7 days |
| `INFORMATION_SCHEMA.TASK_HISTORY()` look-back | 7 days |
| `INFORMATION_SCHEMA.COPY_HISTORY()` / `LOAD_HISTORY` look-back | **14 days** |
| `INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY()` look-back | **6 months** |
| Max tags per object | **50** |
| Max tag value length | **256** characters |
| Default `TIMEZONE` | America/Los_Angeles |

## Pipelines and programmability

| Item | Value |
|---|---|
| Max tasks in a task graph | **1,000** † |
| Max predecessors / children per task | **100** / **100** |
| Shortest `n MINUTE` schedule (classic) | **1 minute** † |
| `SUSPEND_TASK_AFTER_NUM_FAILURES` default | 10 |
| Dynamic table minimum target lag | **1 minute** † |
| `LOCK_TIMEOUT` default | **43,200 s** (12 h) |
| Stream metadata columns | 3 (`ACTION`, `ISUPDATE`, `ROW_ID`) |
| FLATTEN output columns | 6 (SEQ, KEY, PATH, INDEX, VALUE, THIS) |

## Sharing and unstructured data

| Item | Value |
|---|---|
| Databases created per share in a consumer | 1 |
| Default reader accounts per provider (commonly cited) | 20 † |
| Scoped URL lifetime | **24 hours** |
| Pre-signed URL default expiry | 3,600 s (1 h) |
| Pre-signed URL max expiry | 604,800 s (7 days) |

## Resource monitors

| Item | Value |
|---|---|
| Who creates them | ACCOUNTADMIN |
| Monitors per warehouse | **1** |
| Account-level monitors | **1** |
| Actions | 3 (NOTIFY, SUSPEND, SUSPEND_IMMEDIATE) |
| Frequencies | DAILY, WEEKLY, MONTHLY, YEARLY, NEVER |
