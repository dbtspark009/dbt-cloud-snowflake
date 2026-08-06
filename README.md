# dbt Cloud + Snowflake + Airflow — end-to-end demo (dbt Cloud version)

Same bronze -> silver -> gold pipeline as before, but wired for **dbt Cloud**,
not dbt Core. If you previously got the `dbt_snowflake_demo.zip`, that one
assumed local dbt + GitHub Actions running dbt commands directly — it will
NOT work as-is with dbt Cloud. This is the corrected version.

## What's different from the dbt Core version

| | dbt Core version | dbt Cloud version (this one) |
|---|---|---|
| Credentials | `profiles.yml` on disk / in CI secrets | Configured once in dbt Cloud UI (Settings -> Connections), key-pair auth |
| Dev/QA/Prod | `--target dev/qa/prod` flag | Separate **Environments** in dbt Cloud UI, each with its own schema |
| CI on pull request | Custom GitHub Actions YAML running `dbt build` | dbt Cloud's built-in **Continuous Integration** job type, "Run on PRs" toggle — no YAML |
| Deploy to prod | GitHub Actions YAML running `dbt build --target prod` | A dbt Cloud **Deploy job**, triggered by Airflow's API call (not dbt Cloud's own scheduler) |
| Airflow's role | Runs `dbt run`/`dbt test` itself via BashOperator | Calls the dbt Cloud API via `DbtCloudRunJobOperator`, dbt Cloud does the actual work |
| Airflow needs dbt installed? | Yes | **No** — it only needs the `apache-airflow-providers-dbt-cloud` package |

## Setup steps

### 1. One-time Snowflake setup
Run `setup_raw_data.sql` in a Snowflake worksheet — unchanged, still just
creates the shared `DEMO_DB.RAW.ORDERS` table.

### 2. Create the dbt Cloud project
- Account Settings -> Projects -> New Project
- Connect Snowflake using **key-pair authentication** (password auth is
  being retired by Snowflake — see the banner in your dbt Cloud dashboard)
- Connect this GitHub repo (push `dbt_project.yml` and `models/` from this
  ZIP into it first)

### 3. Create three Environments (dbt Cloud UI, not a file)
- **Development** — used by Studio's IDE, personal sandbox, schema `DEV`
- **QA** (Deployment environment) — schema `QA`
- **Production** (Deployment environment) — schema `PROD`

Combined with the `+schema:` config in `dbt_project.yml`, this produces
`DEV_BRONZE/SILVER/GOLD`, `QA_BRONZE/SILVER/GOLD`, `PROD_BRONZE/SILVER/GOLD`
— same result as the dbt Core version, just configured in the UI.

### 4. Create the CI job (this is your quality gate)
On the **QA** environment: New Job -> type **Continuous Integration** ->
enable **"Run on Pull Requests"**. Every PR against `main` now automatically
runs `dbt build` against QA and reports pass/fail directly on the PR in
GitHub — replacing what the old `ci_pull_request.yml` did by hand.

### 5. Create the Production job
On the **Production** environment: New Job -> type **Deploy** -> command
`dbt build`. **Turn its schedule OFF** — Airflow will trigger it instead
(so it doesn't run twice). Copy the Job ID from the URL.

### 6. Wire up Airflow
- In Airflow: Admin -> Connections -> new **dbt Cloud** connection, with
  your dbt Cloud account ID + an API token
- Install `apache-airflow-providers-dbt-cloud` (see `airflow/requirements.txt`)
- Drop `airflow/dags/dbt_cloud_prod_trigger_dag.py` into your Airflow
  `dags/` folder, and update `DBT_CLOUD_PROD_JOB_ID` with the ID from step 5

## Directory map

```
setup_raw_data.sql              one-time raw table creation (unchanged)
dbt_project.yml                 bronze/silver/gold schema config (unchanged)
models/
  bronze/                       source() pass-through
  silver/                       dedup + business rules, via ref()
  gold/                         aggregated, BI-facing, via ref()
airflow/
  requirements.txt              only the dbt Cloud provider, no dbt itself
  dags/
    dbt_cloud_prod_trigger_dag.py   calls dbt Cloud API on a schedule
```

Note there is **no `.github/workflows/` folder** and **no `profiles.yml`**
in this version — dbt Cloud replaces both.

## Going further
- Split the single Production job into 3 (bronze/silver/gold) if you want
  each layer visible as its own Airflow task
- Use `wait_for_termination=False` + a separate sensor if you want Airflow
  to move on to other tasks while dbt Cloud runs asynchronously
- Add a Slack notification in dbt Cloud itself (Settings -> Notifications)
  as a second, independent alert channel alongside Airflow's own alerting
