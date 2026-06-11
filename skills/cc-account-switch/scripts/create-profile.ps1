<#
.SYNOPSIS
  Create an additional Claude Code account profile dir and symlink shared config.
.DESCRIPTION
  Idempotent. Never modifies the source dir. Symlinks on Windows need either
  Developer Mode enabled or an elevated shell.
.PARAMETER Dir
  REQUIRED. Config dir for the new profile (the CLAUDE_CONFIG_DIR value).
.PARAMETER From
  Source/primary config dir. Default: ~\.claude
.PARAMETER Share
  Items to symlink. Default share-set below.
.EXAMPLE
  .\create-profile.ps1 -Dir "$HOME\.claude-work"
#>
param(
  [Parameter(Mandatory=$true)][string]$Dir,
  [string]$From = (Join-Path $HOME ".claude"),
  [string[]]$Share = @("settings.json","skills","commands","hooks","plugins","CLAUDE.md",".mcp.json","mcp-servers")
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $From)) { throw "source dir not found: $From" }
$DirFull  = [System.IO.Path]::GetFullPath($Dir)
$FromFull = [System.IO.Path]::GetFullPath($From)
if ($DirFull -eq $FromFull) { throw "-Dir must differ from -From ($From)" }

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Write-Host "profile dir: $Dir"
Write-Host "source:      $From"
Write-Host "symlinking shared items:"

foreach ($item in $Share) {
  $src = Join-Path $From $item
  $dst = Join-Path $Dir  $item
  if (Test-Path $src) {
    if (Test-Path $dst) { Remove-Item $dst -Force -Recurse -ErrorAction SilentlyContinue }
    try {
      New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
      Write-Host "  linked  $item"
    } catch {
      Write-Warning "  FAILED  $item — enable Developer Mode or run elevated. ($($_.Exception.Message))"
    }
  } else {
    Write-Host "  skip    $item (not in source)"
  }
}

Write-Host ""
Write-Host "done. Not shared (per-account): .claude.json, projects, history.jsonl, sessions, telemetry"
Write-Host "Next: set CLAUDE_CONFIG_DIR=$Dir (via a trigger), open a fresh shell, run 'claude' then '/login'."
