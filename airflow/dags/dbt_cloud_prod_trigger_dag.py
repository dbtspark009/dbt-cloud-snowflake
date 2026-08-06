"""
dbt_cloud_prod_trigger_dag.py

WHAT THIS DOES DIFFERENTLY FROM THE dbt-CORE VERSION:
- Airflow does NOT run `dbt run`/`dbt test` itself, and does NOT need
  dbt or Snowflake credentials installed on the Airflow worker at all.
- Instead, it calls the dbt Cloud API to say "go run this job", then
  polls dbt Cloud until that job finishes (success/fail).
- All the actual SQL execution, credentials, and environment logic
  live entirely inside dbt Cloud — Airflow is just the scheduler/trigger.

PREREQUISITE (one-time, in the Airflow UI):
  Admin -> Connections -> Create:
    Connection Id:   dbt_cloud_default
    Connection Type: dbt Cloud
    Account ID:      <your dbt Cloud account id>
    API Token:       <a dbt Cloud service token, Job Admin scope is enough>

PREREQUISITE (one-time, in dbt Cloud):
  Create a Deploy job on your Production environment (e.g. "prod_build",
  running `dbt build`). Turn its own schedule OFF — Airflow owns the
  trigger now, so you don't want dbt Cloud firing it too. Copy the
  Job ID from the job's URL and paste it below.
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator

# Replace with the Job ID from your dbt Cloud "Production Build" job.
DBT_CLOUD_PROD_JOB_ID = 123456   # <-- update this

default_args = {
    "owner": "data-eng",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    # "on_failure_callback": slack_alert_fn,   # plug in Slack/PagerDuty here
}

with DAG(
    dag_id="dbt_cloud_prod_trigger",
    description="Triggers the dbt Cloud production job (bronze->silver->gold) on a schedule",
    default_args=default_args,
    schedule="0 6 * * *",          # every day at 06:00
    start_date=datetime(2026, 8, 1),
    catchup=False,
    tags=["dbt-cloud", "snowflake", "prod"],
) as dag:

    trigger_prod_job = DbtCloudRunJobOperator(
        task_id="trigger_dbt_cloud_prod_job",
        dbt_cloud_conn_id="dbt_cloud_default",
        job_id=DBT_CLOUD_PROD_JOB_ID,
        wait_for_termination=True,   # task stays "running" in Airflow until dbt Cloud finishes
        timeout=3600,                # give up waiting after 1 hour
        check_interval=30,           # poll dbt Cloud every 30s for status
    )

    # Single task for now — dbt Cloud's own job steps handle bronze -> silver
    # -> gold sequencing internally (via the DAG dbt itself builds from ref()).
    # If you later want each LAYER visible as its own Airflow task, split this
    # into 3 dbt Cloud jobs (one per layer) and chain 3 operators instead.
    trigger_prod_job
