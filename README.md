# Modern ELT Pipeline on GCP: Airbyte → BigQuery → Dataform

An end-to-end ELT pipeline that moves e-commerce data from an operational **PostgreSQL** database into **BigQuery** with **Airbyte**, models it with **Dataform**, and orchestrates both steps with **Apache Airflow**.

> 🚧 **Status: In progress.** The source database, Dataform models and Airflow DAG are in this repo. GCP deployment screenshots and results are being added.

## Architecture

```
┌──────────────┐   incremental sync   ┌──────────────────┐   SQLX models   ┌──────────────────────────┐
│  PostgreSQL  │ ───────────────────▶ │ BigQuery  `raw`  │ ──────────────▶ │ `staging` ──▶ `marts`    │
│ (e-commerce) │       Airbyte        │  (landing zone)  │    Dataform     │ (star schema + tests)    │
└──────────────┘                      └──────────────────┘                 └──────────────────────────┘
        ▲                                                                              │
        └──────────────────────────── Apache Airflow (daily DAG) ─────────────────────┘
                    1) trigger Airbyte sync  →  2) compile & run Dataform workflow
```

## Tech Stack

| Layer | Tool |
|---|---|
| Source | PostgreSQL 16 (Docker) |
| Ingestion (EL) | Airbyte, incremental sync (cursor: `updated_at`) |
| Warehouse | Google BigQuery |
| Transformation (T) | Dataform (SQLX), assertions for data quality |
| Orchestration | Apache Airflow (Airbyte + Google providers) |
| Security | Least-privilege GCP service accounts (IAM) |

## Data Model

**Source tables (`raw`)**: `customers`, `products`, `orders`, `order_items`

**Staging (`staging`)**: cleaned, typed and renamed views: `stg_customers`, `stg_products`, `stg_orders`, `stg_order_items`

**Marts (`marts`)**: star schema
- `fct_order_items`: one row per order line, **partitioned by `order_date`** and **clustered by `customer_id`, `product_id`**, built incrementally
- `dim_customers`, `dim_products`

**Data quality**: Dataform assertions (`uniqueKey`, `nonNull`, `rowConditions`) run on every workflow execution.

## Repository Structure

```
├── docker-compose.yml          # PostgreSQL source with seed data
├── postgres/init.sql           # schema + sample e-commerce data
├── dataform/
│   ├── workflow_settings.yaml
│   └── definitions/
│       ├── sources/            # declarations of Airbyte raw tables
│       ├── staging/            # stg_* views + assertions
│       └── marts/              # fact & dimension tables
└── airflow/dags/elt_pipeline.py
```

## How to Run

1. **Start the source DB**
   ```bash
   docker compose up -d
   ```
2. **Airbyte**: install Airbyte locally (`abctl local install`), then create:
   - Source: PostgreSQL (`localhost:5432`, db `ecommerce`)
   - Destination: BigQuery (dataset `raw`, service-account key)
   - Connection: *Incremental | Append + Deduped*, cursor `updated_at`, primary key `id`
3. **Dataform**: create a Dataform repository in GCP, connect it to this repo's `dataform/` folder, and set `defaultProject` in `workflow_settings.yaml`.
4. **Airflow**: set the variables `AIRBYTE_CONNECTION_ID`, `GCP_PROJECT_ID`, `GCP_REGION`, `DATAFORM_REPOSITORY_ID`, then enable the `airbyte_bigquery_dataform_elt` DAG.

## IAM (least privilege)

| Service account | Roles |
|---|---|
| `airbyte-loader` | BigQuery Data Editor (dataset `raw` only), BigQuery Job User |
| `dataform-runner` | BigQuery Data Viewer (`raw`), Data Editor (`staging`, `marts`), Job User |
| `airflow-orchestrator` | Dataform Editor |

## Author

**Atef Ali Mousa**, Data Engineer · [LinkedIn](https://www.linkedin.com/in/atef-mousa) · [GitHub](https://github.com/Atef-Mousa)
