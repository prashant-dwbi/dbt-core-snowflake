<#
.SYNOPSIS
    Unblocks the dbt venv executables and excludes the venv folder from Windows Defender
    so dbt.exe stops being blocked/flagged on every run.

.NOTES
    Must be run from an Administrator PowerShell window (Add-MpPreference requires elevation).
#>

$venvPath = Join-Path $PSScriptRoot "..\dbt-env" | Resolve-Path

Write-Host "Target venv: $venvPath"

# 1. Remove the "downloaded from the internet" mark-of-the-web flag from venv scripts
Write-Host "Unblocking files under $venvPath\Scripts ..."
Get-ChildItem -Path (Join-Path $venvPath "Scripts") -Recurse | Unblock-File

# 2. Check whether Defender already quarantined/flagged anything related to dbt
Write-Host "Checking Defender threat history for dbt-related detections ..."
Get-MpThreatDetection | Where-Object { $_.Resources -like "*dbt*" }

# 3. Exclude the venv folder from Defender scanning
Write-Host "Adding Defender exclusion for $venvPath ..."
Add-MpPreference -ExclusionPath $venvPath

# 4. Optional: exclude the dbt.exe process specifically (tighter scope than the whole folder)
$dbtExe = Join-Path $venvPath "Scripts\dbt.exe"
if (Test-Path $dbtExe) {
    Write-Host "Adding Defender process exclusion for $dbtExe ..."
    Add-MpPreference -ExclusionProcess $dbtExe
}

# 5. Show current exclusions for verification
Write-Host "`nCurrent Defender path exclusions:"
(Get-MpPreference).ExclusionPath

Write-Host "`nCurrent Defender process exclusions:"
(Get-MpPreference).ExclusionProcess

Write-Host "`nDone. Re-open a normal (non-admin) terminal and run 'dbt --version' to confirm."
