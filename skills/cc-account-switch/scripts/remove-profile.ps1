<#
.SYNOPSIS
  Tear down a profile created by cc-account-switch (Windows/PowerShell).
.DESCRIPTION
  Reverses create-profile + add-trigger + install-statusline. Idempotent.
  Backs up edited files. Refuses to touch the primary (~\.claude) dir.
.PARAMETER Dir
  REQUIRED. Profile config dir to remove (e.g. ~\.claude-work).
.PARAMETER Rc
  PowerShell profile to strip trigger blocks from. Default: $PROFILE
.PARAMETER Statusline
  Status-line script to strip the account block from. Default: ~\.claude\hooks\statusline.ps1
.PARAMETER KeepDir
  Do everything except deleting the profile dir.
.PARAMETER Yes
  Required to actually delete the profile dir.
.PARAMETER DryRun
  Print actions, change nothing.
.EXAMPLE
  .\remove-profile.ps1 -Dir "$HOME\.claude-work" -Yes
#>
param(
  [Parameter(Mandatory=$true)][string]$Dir,
  [string]$Rc = $PROFILE,
  [string]$Statusline = (Join-Path $HOME ".claude\hooks\statusline.ps1"),
  [switch]$KeepDir,
  [switch]$Yes,
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"

$dirAbs     = [System.IO.Path]::GetFullPath($Dir)
$primaryAbs = [System.IO.Path]::GetFullPath((Join-Path $HOME ".claude"))
if ($dirAbs -eq $primaryAbs -or $dirAbs -eq [System.IO.Path]::GetFullPath($HOME)) {
  throw "refusing to remove primary/home dir ($dirAbs)"
}

function Strip-Blocks([string]$file, [string]$label) {
  if (-not (Test-Path $file)) { Write-Host "  ${label}: $file not found, skip"; return }
  $lines = Get-Content $file
  # Also match legacy blocks written before the skill was renamed from claude-account-switch.
  if (-not ($lines -match '^# >>> (cc|claude)-account-switch:')) { Write-Host "  ${label}: no skill blocks"; return }
  if ($DryRun) { Write-Host "[dry-run] would strip cc-account-switch blocks from $file"; return }
  Copy-Item $file "$file.bak" -Force
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($l in $lines) {
    if ($l -match '^# >>> (cc|claude)-account-switch:') { $skip = $true }
    if (-not $skip) { $out.Add($l) }
    if ($l -match '^# <<< (cc|claude)-account-switch:') { $skip = $false }
  }
  Set-Content -Path $file -Value $out -Encoding UTF8
  Write-Host "  ${label}: stripped blocks from $file (backup: $file.bak)"
}

Write-Host "Removing profile: $Dir"
if ($DryRun) { Write-Host "(dry run — no changes)" }
Write-Host ""

Write-Host "1) PowerShell profile trigger:"
Strip-Blocks $Rc "rc"

Write-Host "2) status-line account block:"
Strip-Blocks $Statusline "statusline"

Write-Host "3) credentials:"
Write-Host "  Windows stores creds in $Dir\.credentials.json — removed with the dir below."
Write-Host "  To de-auth without deleting the dir, run 'claude' (with CLAUDE_CONFIG_DIR set) then '/logout'."

Write-Host "4) profile dir:"
if ($KeepDir) {
  Write-Host "  -KeepDir set, leaving $Dir"
} elseif ($Yes) {
  if ($DryRun) { Write-Host "[dry-run] would Remove-Item -Recurse -Force $Dir" }
  else { Remove-Item -Recurse -Force $Dir; Write-Host "  deleted $Dir" }
} else {
  Write-Host "  NOT deleted (pass -Yes). Holds that account's .claude.json, sessions, projects, history — permanent."
}

Write-Host ""
Write-Host "done. Open a fresh PowerShell to drop the trigger from the environment."
