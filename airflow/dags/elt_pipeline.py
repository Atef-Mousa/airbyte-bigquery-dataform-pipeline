"""
Daily ELT pipeline: Airbyte (PostgreSQL -> BigQuery raw) then Dataform (raw -> staging -> marts).

Requires:
  apache-airflow-providers-airbyte
  apache-airflow-providers-google
Airflow Variables:
  AIRBYTE_CONNECTION_ID, GCP_PROJECT_ID, GCP_REGION, DATAFORM_REPOSITORY_ID
Airflow Connections:
  airbyte_default, google_cloud_default
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)

PROJECT_ID = Variable.get("GCP_PROJECT_ID")
REGION = Variable.get("GCP_REGION", default_var="us-central1")
REPOSITORY_ID = Variable.get("DATAFORM_REPOSITORY_ID")

default_args = {
    "owner": "atef",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="airbyte_bigquery_dataform_elt",
    description="PostgreSQL -> BigQuery (Airbyte) -> Dataform models",
    start_date=datetime(2026, 11, 1),
    schedule="@daily",
    catchup=False,
    default_args=default_args,
    tags=["elt", "airbyte", "bigquery", "dataform"],
) as dag:

    # 1) Extract & Load: sync PostgreSQL tables into BigQuery `raw`
    airbyte_sync = AirbyteTriggerSyncOperator(
        task_id="airbyte_sync_postgres_to_bigquery",
        airbyte_conn_id="airbyte_default",
        connection_id=Variable.get("AIRBYTE_CONNECTION_ID"),
        asynchronous=False,
        timeout=3600,
        wait_seconds=10,
    )

    # 2) Compile the Dataform project from the main branch
    compile_dataform = DataformCreateCompilationResultOperator(
        task_id="create_compilation_result",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        compilation_result={"git_commitish": "main"},
    )

    # 3) Transform: run all Dataform actions (staging, marts, assertions)
    run_dataform = DataformCreateWorkflowInvocationOperator(
        task_id="create_workflow_invocation",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={
            "compilation_result": "{{ task_instance.xcom_pull('create_compilation_result')['name'] }}"
        },
    )

    airbyte_sync >> compile_dataform >> run_dataform
