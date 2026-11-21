# Modern ELT Pipeline on GCP: Airbyte → BigQuery → Dataform

An end-to-end ELT pipeline that moves e-commerce data from an operational **PostgreSQL** database into **BigQuery** with **Airbyte**, models it with **Dataform**, and orchestrates both steps with **Apache Airflow**.

> 🚧 **Status: In progress.** Code is being pushed; GCP deployment screenshots and results will follow.

## Architecture

```
PostgreSQL ──(Airbyte, incremental)──▶ BigQuery `raw` ──(Dataform SQLX)──▶ `staging` ──▶ `marts`
     ▲                                                                              │
     └──────────── Apache Airflow (daily DAG): Airbyte sync → Dataform run ─────────┘
```

## Tech Stack

| Layer | Tool |
|---|---|
| Source | PostgreSQL 16 (Docker) |
| Ingestion (EL) | Airbyte, incremental sync (cursor: `updated_at`) |
| Warehouse | Google BigQuery |
| Transformation (T) | Dataform (SQLX) + assertions for data quality |
| Orchestration | Apache Airflow (Airbyte + Google providers) |
| Security | Least-privilege GCP service accounts (IAM) |

## Data Model

- **raw**: `customers`, `products`, `orders`, `order_items` (landed by Airbyte)
- **staging**: cleaned and typed views `stg_*`
- **marts** (star schema):
  - `fct_order_items`: incremental, **partitioned by `order_date`**, **clustered by `customer_id`, `product_id`**
  - `dim_customers`, `dim_products`
- **Data quality**: Dataform assertions (`uniqueKey`, `nonNull`, `rowConditions`) on every run

## IAM (least privilege)

| Service account | Roles |
|---|---|
| `airbyte-loader` | BigQuery Data Editor (`raw` only), Job User |
| `dataform-runner` | Data Viewer (`raw`), Data Editor (`staging`, `marts`), Job User |
| `airflow-orchestrator` | Dataform Editor |

## Author

**Atef Ali Mousa**, Data Engineer · [LinkedIn](https://www.linkedin.com/in/atef-mousa) · [GitHub](https://github.com/Atef-Mousa)
