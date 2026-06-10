<#
.SYNOPSIS
  Append a guarded CLAUDE_CONFIG_DIR switch trigger to the PowerShell profile.
.DESCRIPTION
  Idempotent (marker-guarded). Backs up $PROFILE before editing.
.PARAMETER Dir
  REQUIRED. Profile config dir (CLAUDE_CONFIG_DIR value).
.PARAMETER Strategy
  terminal | directory | alias
.PARAMETER Match
  terminal: ignored (uses WT_SESSION presence). directory: path prefix. alias: ignored.
.PARAMETER Name
  alias: function name. Default: claude-<Label>
.PARAMETER Label
  Identifier in marker comments + default alias name. Default: work
.PARAMETER Rc
  Profile file to edit. Default: $PROFILE
.EXAMPLE
  .\add-trigger.ps1 -Dir "$HOME\.claude-work" -Strategy alias
  .\add-trigger.ps1 -Dir "$HOME\.claude-work" -Strategy directory -Match "$HOME\work"
  .\add-trigger.ps1 -Dir "$HOME\.claude-work" -Strategy terminal
#>
param(
  [Parameter(Mandatory=$true)][string]$Dir,
  [Parameter(Mandatory=$true)][ValidateSet("terminal","directory","alias")][string]$Strategy,
  [string]$Match = "",
  [string]$Name = "",
  [string]$Label = "work",
  [string]$Rc = $PROFILE
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Rc)) { New-Item -ItemType File -Force -Path $Rc | Out-Null }
$start = "# >>> claude-account-switch: $Strategy trigger ($Label) >>>"
$end   = "# <<< claude-account-switch: $Strategy trigger ($Label) <<<"

if ((Get-Content $Rc -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($start)) {
  Write-Host "trigger already present in $Rc ($Strategy/$Label) — nothing to do."; exit 0
}

switch ($Strategy) {
  "terminal" {
    $block = @"
$start
if (`$env:WT_SESSION) { `$env:CLAUDE_CONFIG_DIR = "$Dir" }
$end
"@
  }
  "directory" {
    if (-not $Match) { throw "directory strategy needs -Match (path prefix)" }
    $block = @"
$start
`$function:prompt = {
  if (`$PWD.Path -like "$Match*") { `$env:CLAUDE_CONFIG_DIR = "$Dir" }
  else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
  "PS `$(`$PWD.Path)> "
}
$end
"@
  }
  "alias" {
    if (-not $Name) { $Name = "claude-$Label" }
    $block = @"
$start
function $Name { `$env:CLAUDE_CONFIG_DIR = "$Dir"; claude @args }
$end
"@
  }
}

Copy-Item $Rc "$Rc.bak" -Force
Add-Content -Path $Rc -Value "`n$block"
Write-Host "appended $Strategy trigger to $Rc:"
Write-Host "----------------------------------------"
Write-Host $block
Write-Host "----------------------------------------"
Write-Host "Open a fresh PowerShell to activate. Backup: $Rc.bak"
Write-Host "NOTE: directory strategy overwrites the prompt function — merge manually if you have a custom prompt."
