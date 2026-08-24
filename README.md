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
