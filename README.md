# dbt-core + Snowflake Setup

Local setup instructions for running this dbt project against Snowflake on Windows.

## Prerequisites

- Python 3.8–3.11
- Access to a Snowflake account (account locator, user, role, warehouse, database, schema)

## 1. Create and activate a virtual environment

```powershell
python -m venv dbt-env
dbt-env\Scripts\Activate.ps1
```

## 2. Install dbt-core and the Snowflake adapter

```powershell
python -m pip install --upgrade pip
python -m pip install dbt-snowflake
```

`dbt-snowflake` pulls in `dbt-core` automatically — no separate install needed.

## 3. Fix Windows Defender blocking `dbt.exe`

If `dbt --version` fails or hangs because Windows Defender flags/blocks the executable in the venv, run [`scripts/unblock-dbt.ps1`](scripts/unblock-dbt.ps1) from an **Administrator PowerShell** window:

```powershell
.\scripts\unblock-dbt.ps1
```

This unblocks the venv's scripts and adds a Defender exclusion for the venv folder so it stops being scanned/blocked on every run.

Since this modifies Windows Defender security settings, you'll need to run this yourself in an elevated (Administrator) PowerShell — it can't be run for you automatically. Here's the script:

```powershell
# Run this in an Administrator PowerShell window

$venvPath = "C:\Users\PrashantKumarPattnai\Documents\bitbucket\dbt-core-snowflake\dbt-env"

# 1. Unblock the dbt executable and related scripts (removes the "downloaded from internet" mark-of-the-web flag)
Get-ChildItem -Path "$venvPath\Scripts" -Recurse | Unblock-File

# 2. Check if Defender already quarantined/detected something related to dbt
Get-MpThreatDetection | Where-Object { $_.Resources -like "*dbt*" }

# 3. Add an exclusion so Defender stops scanning/blocking this venv folder
Add-MpPreference -ExclusionPath $venvPath

# 4. (Optional) Exclude the specific exe if you'd rather scope it tighter than the whole folder
Add-MpPreference -ExclusionProcess "$venvPath\Scripts\dbt.exe"

# 5. Verify the exclusions were added
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess
```

After running this, go back to your normal (non-admin) terminal and try:

```powershell
dbt --version
```

## 4. Verify installation

```powershell
dbt --version
```

You should see both `dbt-core` and `dbt-snowflake` plugin versions listed.

## 5. Configure the Snowflake connection profile

Instead of the default `%USERPROFILE%\.dbt\profiles.yml`, this project keeps its profile in-repo at [`dbt_sales_mart/profiles.yml`](dbt_sales_mart/profiles.yml), with all credentials pulled from environment variables via `env_var()` — no secrets are stored in the file itself:

```yaml
dbt_sales_mart:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      authenticator: "{{ env_var('SNOWFLAKE_AUTHENTICATOR', 'externalbrowser') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD', '') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      schema: "{{ env_var('SNOWFLAKE_SCHEMA') }}"
      threads: 4
      client_session_keep_alive: false
```

Authentication uses `externalbrowser` (SSO) by default — no password is stored or required. Running `dbt debug`/`dbt run` will pop open a browser window for you to log in to Snowflake; the session is then cached by the Snowflake driver for a while. If your account doesn't have SSO configured and you need password auth instead, swap the `authenticator` line for `password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"` and set `SNOWFLAKE_PASSWORD` — but never commit real values into `set-snowflake-env.example.ps1`, only into the gitignored `set-snowflake-env.ps1`.

Set the env vars for your session by copying the template and filling in real values:

```powershell
Copy-Item scripts\set-snowflake-env.example.ps1 scripts\set-snowflake-env.ps1
# edit scripts\set-snowflake-env.ps1 with your real account/user/password/etc.
. .\scripts\set-snowflake-env.ps1
```

`scripts\set-snowflake-env.ps1` is gitignored so real credentials never get committed — only the `.example.ps1` template is tracked.

Because the profile lives in the project instead of `~/.dbt`, point dbt at it with `--profiles-dir` (or set `DBT_PROFILES_DIR` once per session so you don't have to repeat the flag):

```powershell
$env:DBT_PROFILES_DIR = "$PWD\dbt_sales_mart"
```

Prefer key-pair auth or SSO over plain passwords for anything beyond local testing.

## 6. Test the connection

```powershell
cd dbt_sales_mart
dbt debug
```

If you didn't set `DBT_PROFILES_DIR`, pass the flag explicitly instead: `dbt debug --profiles-dir .`

## 7. Run and test the project

```powershell
dbt run
dbt test
dbt docs generate
dbt docs serve
```

## 8. CI pipeline

A GitHub Actions workflow at [`.github/workflows/dbt-ci.yml`](.github/workflows/dbt-ci.yml) runs `dbt debug` and `dbt build` (run + test) against Snowflake on every pull request into `main`. It builds into an isolated `CI` schema so it never touches the `DBT` dev schema or anything else.

**Auth:** the pipeline uses key-pair auth with a dedicated, least-privilege Snowflake service user (`DBT_CI_SVC` / role `DBT_CI_ROLE`) instead of a personal account or password — CI runners are headless, so interactive `externalbrowser` SSO won't work there.

**Profile:** [`ci/profiles.yml`](ci/profiles.yml) is committed to the repo and contains no secrets — every value is pulled from an environment variable via `env_var()`, the same pattern used for local dev. The workflow sets `DBT_PROFILES_DIR` to that folder.

### One-time setup

1. Generate an RSA key pair (run locally, not committed):
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
   ```
2. Create the service user/role in Snowflake, using the public key body (strip the `-----BEGIN/END-----` lines):
   ```sql

   CREATE ROLE IF NOT EXISTS DBT_CI_ROLE;

   CREATE USER IF NOT EXISTS DBT_CI_SVC
     RSA_PUBLIC_KEY = '<base64 body of rsa_key.pub>'
     DEFAULT_ROLE = DBT_CI_ROLE
     DEFAULT_WAREHOUSE = COMPUTE_WH
     COMMENT = 'Service account for GitHub Actions dbt CI';

   GRANT ROLE DBT_CI_ROLE TO USER DBT_CI_SVC;

   GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_CI_ROLE;
   GRANT USAGE ON DATABASE SALES_MART_DEV TO ROLE DBT_CI_ROLE;
   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_CI_ROLE;

   CREATE SCHEMA IF NOT EXISTS SALES_MART_DEV.CI;
   GRANT ALL ON SCHEMA SALES_MART_DEV.CI TO ROLE DBT_CI_ROLE;
   GRANT CREATE TABLE, CREATE VIEW ON SCHEMA SALES_MART_DEV.CI TO ROLE DBT_CI_ROLE;
   ```
3. Add these as GitHub repo secrets (**Settings → Secrets and variables → Actions**):

   | Secret | Value |
   |---|---|
   | `SNOWFLAKE_ACCOUNT` | your account locator |
   | `SNOWFLAKE_CI_USER` | `DBT_CI_SVC` |
   | `SNOWFLAKE_CI_PRIVATE_KEY` | full contents of `rsa_key.p8`, including the `BEGIN/END PRIVATE KEY` lines |
   | `SNOWFLAKE_CI_PRIVATE_KEY_PASSPHRASE` | omit this secret entirely — GitHub rejects blank secret values, and the workflow/profile already default to an empty passphrase when it's unset (key generated with `-nocrypt`) |
   | `SNOWFLAKE_CI_ROLE` | `DBT_CI_ROLE` |
   | `SNOWFLAKE_CI_DATABASE` | `SALES_MART_DEV` |
   | `SNOWFLAKE_CI_WAREHOUSE` | `COMPUTE_WH` |
   | `SNOWFLAKE_CI_SCHEMA` | `CI` |

Once the secrets are in place, opening a PR against `main` triggers the workflow automatically.

## 9. CD pipeline

A second GitHub Actions workflow at [`.github/workflows/dbt-cd.yml`](.github/workflows/dbt-cd.yml) deploys to production whenever a change is pushed/merged to `main`. It builds into a separate Snowflake **database** (`SALES_MART_PROD`), distinct from both your personal `DBT` dev schema and the CI job's `CI` schema — a full database split rather than just another schema, so prod and non-prod credentials can never reach each other's data even by mistake.

**Approval gate:** the deploy job runs under the `production` GitHub Environment, which is configured with a required reviewer. After a merge to `main`, the workflow pauses until someone manually approves the run before it touches Snowflake — see setup step 3 below.

**Auth:** uses its own dedicated, least-privilege service account (`DBT_PROD_SVC` / role `DBT_PROD_ROLE`), separate from the CI service account, scoped only to `SALES_MART_PROD`.

**Profile:** [`cd/profiles.yml`](cd/profiles.yml) is committed and secrets-free, same `env_var()` pattern as `ci/profiles.yml`.

**Docs:** after a successful build, the workflow runs `dbt docs generate` and publishes the docs site to GitHub Pages via a second job (`publish-docs`), gated on the deploy job succeeding.

### One-time setup

1. Generate a second, separate RSA key pair for the prod service account (keep it distinct from the CI key):
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key_prod.p8 -nocrypt
   openssl rsa -in rsa_key_prod.p8 -pubout -out rsa_key_prod.pub
   ```
2. Create the prod database, schema, service user and role in Snowflake:
   ```sql
   CREATE DATABASE IF NOT EXISTS SALES_MART_PROD;
   CREATE SCHEMA IF NOT EXISTS SALES_MART_PROD.MARTS;

   CREATE ROLE IF NOT EXISTS DBT_PROD_ROLE;

   CREATE USER IF NOT EXISTS DBT_PROD_SVC
     RSA_PUBLIC_KEY = '<base64 body of rsa_key_prod.pub>'
     DEFAULT_ROLE = DBT_PROD_ROLE
     DEFAULT_WAREHOUSE = COMPUTE_WH
     COMMENT = 'Service account for GitHub Actions dbt CD (production deploys)';

   GRANT ROLE DBT_PROD_ROLE TO USER DBT_PROD_SVC;

   GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_PROD_ROLE;
   GRANT USAGE ON DATABASE SALES_MART_PROD TO ROLE DBT_PROD_ROLE;
   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_PROD_ROLE;

   GRANT ALL ON SCHEMA SALES_MART_PROD.MARTS TO ROLE DBT_PROD_ROLE;
   GRANT CREATE TABLE, CREATE VIEW ON SCHEMA SALES_MART_PROD.MARTS TO ROLE DBT_PROD_ROLE;
   ```
3. Create the `production` GitHub Environment with a required reviewer (**Settings → Environments → New environment**, name it `production`, then under "Deployment protection rules" add yourself or another reviewer as a required reviewer). Add the secrets below scoped to this environment (rather than repo-wide) so they're only reachable once a run is approved:

   | Secret | Value |
   |---|---|
   | `SNOWFLAKE_ACCOUNT` | your account locator (can reuse the repo-level secret) |
   | `SNOWFLAKE_CD_USER` | `DBT_PROD_SVC` |
   | `SNOWFLAKE_CD_PRIVATE_KEY` | full contents of `rsa_key_prod.p8`, including the `BEGIN/END PRIVATE KEY` lines |
   | `SNOWFLAKE_CD_PRIVATE_KEY_PASSPHRASE` | omit this secret entirely — GitHub rejects blank secret values, and the workflow/profile already default to an empty passphrase when it's unset (key generated with `-nocrypt`) |
   | `SNOWFLAKE_CD_ROLE` | `DBT_PROD_ROLE` |
   | `SNOWFLAKE_CD_DATABASE` | `SALES_MART_PROD` |
   | `SNOWFLAKE_CD_WAREHOUSE` | `COMPUTE_WH` |
   | `SNOWFLAKE_CD_SCHEMA` | `MARTS` |
4. Enable GitHub Pages (**Settings → Pages → Source → GitHub Actions**) so the `publish-docs` job has somewhere to deploy to.

Once merged to `main`, the `deploy` job will wait for approval in the **Actions** tab; approving it runs `dbt build` against `SALES_MART_PROD` and then publishes fresh docs.

## 10. Rotating service account keys

Snowflake supports two active public keys per user (`RSA_PUBLIC_KEY` and `RSA_PUBLIC_KEY_2`), which lets you swap in a new key pair without a window where CI/CD is broken. Rotate the CI key (`DBT_CI_SVC`) and the CD key (`DBT_PROD_SVC`) independently — do one at a time so a mistake in one doesn't take down both pipelines.

Rotate a key immediately if it's ever exposed — pasted into a chat, shown in an IDE selection/screenshot, committed to git (even briefly), or logged anywhere outside the GitHub secret store.

1. Generate a new key pair locally (use a name that won't collide with the old one, e.g. `rsa_key_ci_new.p8` / `rsa_key_prod_new.p8`):
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key_ci_new.p8 -nocrypt
   openssl rsa -in rsa_key_ci_new.p8 -pubout -out rsa_key_ci_new.pub
   ```
2. Attach the new public key to the service user's secondary key slot, leaving the old key active:
   ```sql
   ALTER USER DBT_CI_SVC SET RSA_PUBLIC_KEY_2 = '<base64 body of rsa_key_ci_new.pub>';
   ```
3. Update the corresponding GitHub secret with the new private key:
   - CI: repo secret `SNOWFLAKE_CI_PRIVATE_KEY` (**Settings → Secrets and variables → Actions**) → paste the full contents of `rsa_key_ci_new.p8`.
   - CD: `SNOWFLAKE_CD_PRIVATE_KEY` on the `production` environment (**Settings → Environments → production**) → paste the full contents of `rsa_key_prod_new.p8`.
4. Confirm the pipeline still works with the new key:
   - CI: open any PR (or push an empty commit to one) and check the `dbt-ci` workflow run passes.
   - CD: merge to `main`, approve the `production` deployment, and check the `dbt-cd` workflow run passes.
5. Once confirmed, remove the old key so it can no longer authenticate:
   ```sql
   ALTER USER DBT_CI_SVC UNSET RSA_PUBLIC_KEY;
   ALTER USER DBT_CI_SVC SET RSA_PUBLIC_KEY = '<base64 body of rsa_key_ci_new.pub>';
   ALTER USER DBT_CI_SVC UNSET RSA_PUBLIC_KEY_2;
   ```
   (Snowflake doesn't let you leave the primary slot empty, so move the new key into `RSA_PUBLIC_KEY` and clear `RSA_PUBLIC_KEY_2` — this also leaves the account ready for the next rotation.) Repeat the equivalent `ALTER USER DBT_PROD_SVC ...` statements for the CD key.
6. Delete the old and new private key files from disk once they're safely in GitHub secrets and Snowflake — they should never be needed locally again. Both `rsa_key*.p8`/`rsa_key*.pub` naming patterns are gitignored, but a deleted file can't leak by accident.

## 11. Orchestrate dbt with Airflow locally (Astronomer)

This repo also includes an [`airflow/`](airflow/) Astro project that runs the dbt project as an Airflow DAG using [astronomer-cosmos](https://astronomer.github.io/astronomer-cosmos/), instead of invoking `dbt` directly from the CLI. Cosmos turns each dbt model/test into its own Airflow task, so you get per-model retries, logs, and a dependency graph in the Airflow UI.

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or another Docker daemon) running
- [Astro CLI](https://www.astronomer.io/docs/astro/cli/install-cli) — the open-source tool that builds and runs Airflow locally in Docker:
  ```powershell
  winget install -e --id Astronomer.Astro
  ```
- Only one local Astro/Airflow project running Docker Compose at a time on the machine. Astro CLI gives each project its own Docker network, but if you have multiple `astro dev start` projects up simultaneously, container-to-container traffic can cross networks and connect to the wrong Postgres — stop other local Astro projects (`astro dev stop` from their folder, or `docker stop <container>`) before starting this one if you hit unexplained database errors.

### How the project is wired up

- [`airflow/Dockerfile`](airflow/Dockerfile) builds a **separate Python virtualenv** (`/usr/local/airflow/dbt_venv`) inside the Airflow image just for `dbt-snowflake`, so dbt's dependency pins never collide with Airflow's own packages.
- [`airflow/requirements.txt`](airflow/requirements.txt) installs `astronomer-cosmos`, the provider that turns a dbt project into Airflow tasks.
- [`airflow/dags/dbt_sales_mart_dag.py`](airflow/dags/dbt_sales_mart_dag.py) defines a `DbtDag` pointed at `/usr/local/airflow/dbt_sales_mart` inside the container, using the dbt executable from the venv above.
- [`airflow/docker-compose.override.yml`](airflow/docker-compose.override.yml) does two things Astro CLI's default compose file doesn't:
  - Pins the local metadata Postgres to `postgres:13` — Airflow 3.3's `db migrate` runs a data migration that calls `gen_random_uuid()`, which the Astro CLI's default `postgres:12.6` image doesn't provide.
  - Volume-mounts the repo's `dbt_sales_mart/` folder (a sibling of `airflow/`, outside its Docker build context) into the scheduler, dag-processor, triggerer, and api-server containers at `/usr/local/airflow/dbt_sales_mart` — so Cosmos can see the actual dbt project, and local edits to models show up without rebuilding the image.
- [`dbt_sales_mart/profiles.yml`](dbt_sales_mart/profiles.yml) is the same profile used for local CLI runs (step 5 above); Astro CLI automatically injects every variable from `airflow/.env` into all of the containers, so the `env_var()` lookups resolve the same way they do outside Docker.

### 1. Set Snowflake credentials for the container

Astro CLI loads `airflow/.env` into every container's environment automatically. It's gitignored, so add your real values there (not in `dbt_sales_mart/profiles.yml`):

```
SNOWFLAKE_ACCOUNT=your_account_locator
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=your_role
SNOWFLAKE_DATABASE=SALES_MART_DEV
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_SCHEMA=DBT
```

### 2. Start Airflow

```powershell
cd airflow
astro dev start
```

This builds the image from the Dockerfile and starts six containers: Postgres (metadata DB), scheduler, dag-processor, api-server (Airflow UI), triggerer, and a one-shot db-migration job that runs `airflow db migrate` and then exits (an `Exited` state for `db-migration` in the next command is expected — it's not a crash).

Once healthy, it prints the local UI URL (e.g. `http://airflow.localhost:<port>`). You can also always reach it directly at **http://localhost:8080/**, regardless of what port the proxy prints. The default login is `admin` / `admin`.

### 3. Verify the environment came up clean

```powershell
astro dev ps
```

All services except `db-migration` should show `running`. Then check the DAG parsed without errors and dbt can actually reach Snowflake:

```powershell
docker exec <project>-scheduler-1 airflow dags list-import-errors
docker exec <project>-scheduler-1 bash -c "cd /usr/local/airflow/dbt_sales_mart && /usr/local/airflow/dbt_venv/bin/dbt debug --profiles-dir ."
```

(`<project>` is the container name prefix Astro CLI generated for this project — find it with `astro dev ps` or `docker ps`.) `dbt debug` should report `Connection test: [OK connection ok]`; the "git" dependency check failing is expected and harmless unless `dbt_sales_mart/packages.yml` starts pulling packages from git.

### 4. Run the dbt DAG

From the UI (http://airflow.localhost:*): find the `dbt_sales_mart` DAG, toggle it **on** (DAGs start paused by default), and click the trigger (▶) button.

From the CLI instead:

```powershell
docker exec <project>-scheduler-1 airflow dags unpause dbt_sales_mart
docker exec <project>-scheduler-1 airflow dags trigger dbt_sales_mart
```

Watch progress with:

```powershell
docker exec <project>-scheduler-1 airflow tasks states-for-dag-run dbt_sales_mart "<dag_run_id>"
```

(`<dag_run_id>` is printed by the `trigger` command, e.g. `manual__2026-08-24T11:58:43.758466+00:00`.) Each dbt model/test appears as its own task (`<model>.run`, `<model>.test`), running in dependency order — staging models first, then intermediate, then marts/facts.

### 5. Stop Airflow

```powershell
astro dev stop
```

This stops and removes the containers but keeps the Postgres volume (DAG history, connections, etc.) for next time. Use `astro dev kill` instead if you also want to wipe that volume and start from a truly clean metadata DB.

## 12. Slim CI, SQL linting, and per-PR staging via Airflow

Three additions to the CI/CD flow described in sections 8–9:

- **Slim CI** — `dbt-ci.yml` only rebuilds models that changed on the PR (plus their downstream dependents), instead of the whole project, by diffing against the manifest from the last successful production build.
- **SQL linting** — `sqlfluff` checks style/conventions on every PR, using the `dbt` templater so it lints the actual rendered SQL.
- **Per-PR Airflow staging** — a second workflow, `dbt-airflow-stage.yml`, spins up an ephemeral local Airflow (via Astro CLI, same setup as section 11) and runs the real `dbt_sales_mart` Cosmos DAG against an isolated schema in a new `SALES_MART_STAGE` database, so the actual orchestration path gets exercised before merge, not just a bare `dbt build`.

### How the stage schema name is derived

[`scripts/derive_schema_name.sh`](scripts/derive_schema_name.sh) takes the PR's branch name and:
- takes the first two `-`-separated tokens, uppercased, joined with `_` — e.g. `JIRA-123-add-a-column` → `JIRA_123`
- falls back to the whole branch name (sanitized the same way) if it has fewer than two tokens — e.g. `hotfix` → `HOTFIX`

Every PR built from the same ticket reuses (and overwrites) the same schema, which is intentional — pushing new commits to the same PR just rebuilds its schema in place. The main risk this doesn't eliminate is two *unrelated* branches that happen to share their first two tokens (e.g. `fix-bug-123` and `fix-bug-456` both derive `FIX_BUG`) — following a consistent `TICKET-NUMBER-description` branch naming convention avoids this in practice. A `concurrency` group keyed on the branch name (in `dbt-airflow-stage.yml`) cancels superseded runs so two pushes to the same PR can't race against the same schema.

Because there's no per-PR cleanup, abandoned schemas in `SALES_MART_STAGE` accumulate over time — periodic manual/scheduled housekeeping (e.g. dropping schemas untouched for 90+ days) is a reasonable later addition, not something this design depends on for correctness.

### How slim CI works

1. On every merge to `main`, `dbt-cd.yml` publishes `target/manifest.json` from the successful production build to a dedicated orphan branch, `previous_release_artifacts` (force-pushed as a single commit each time — only the latest manifest is ever needed).
2. On every PR, `dbt-ci.yml` checks out that branch and runs:
   ```bash
   dbt build --select "state:modified+" --state ../previous_artifacts --defer --favor-state
   ```
   `state:modified+` selects changed models and everything downstream of them. `--defer --favor-state` resolves `ref()`s for everything *not* selected against production (`SALES_MART_PROD`), which is why `DBT_CI_ROLE` needs read access there (see setup below).
3. If `previous_release_artifacts` doesn't exist yet (e.g. the very first run), CI automatically falls back to a full `dbt build`.

Note this still requires a live Snowflake connection — `dbt compile`/`build`'s state comparison and deferred `ref()` resolution both need to reach Snowflake, so this doesn't remove Snowflake as a CI dependency, it just reduces how much gets rebuilt.

### One-time setup

1. Generate a dedicated RSA key pair for the stage service account (same key-pair pattern as CI/CD — see setup steps in sections 8–9 — keep it distinct from both):
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key_stage.p8 -nocrypt
   openssl rsa -in rsa_key_stage.p8 -pubout -out rsa_key_stage.pub
   ```
2. Run [`snowflake/setup_stage_and_slim_ci.sql`](snowflake/setup_stage_and_slim_ci.sql) (with the public key body pasted in) — it grants `DBT_CI_ROLE` read access to `SALES_MART_PROD` (for slim CI's `--defer`), and creates the new `SALES_MART_STAGE` database plus a dedicated `DBT_STAGE_SVC` / `DBT_STAGE_ROLE` service account, authenticated by key pair like the CI/CD accounts (no passwords).
3. Add these repo secrets (**Settings → Secrets and variables → Actions**) for the stage workflow:

   | Secret | Value |
   |---|---|
   | `SNOWFLAKE_STAGE_USER` | `DBT_STAGE_SVC` |
   | `SNOWFLAKE_STAGE_PRIVATE_KEY` | full contents of `rsa_key_stage.p8`, including the `BEGIN/END PRIVATE KEY` lines |
   | `SNOWFLAKE_STAGE_PRIVATE_KEY_PASSPHRASE` | omit this secret entirely — the workflow/profile default to an empty passphrase when it's unset (key generated with `-nocrypt`) |
   | `SNOWFLAKE_STAGE_ROLE` | `DBT_STAGE_ROLE` |
   | `SNOWFLAKE_STAGE_DATABASE` | `SALES_MART_STAGE` |
   | `SNOWFLAKE_STAGE_WAREHOUSE` | `COMPUTE_WH` |

   (`SNOWFLAKE_ACCOUNT` is reused from the existing repo secret.)
4. No action needed for `previous_release_artifacts` — `dbt-cd.yml` creates it automatically on the next successful merge to `main`.

The stage job authenticates via a `stage` target in `dbt_sales_mart/profiles.yml` (key-pair auth, distinct from the `dev` target used for local development). The Airflow DAG ([`airflow/dags/dbt_sales_mart_dag.py`](airflow/dags/dbt_sales_mart_dag.py)) picks whichever target the `DBT_TARGET` env var names, defaulting to `dev` — the stage workflow sets `DBT_TARGET=stage`.

Once these are in place, every PR against `main` runs three checks: `dbt-ci.yml` (slim build + lint), `dbt-cd.yml` (only on merge), and `dbt-airflow-stage.yml` (ephemeral Airflow run against the PR's own `SALES_MART_STAGE` schema).
