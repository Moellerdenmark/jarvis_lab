param(
  [string]$Repo = "C:\Users\gubbi\jarvis_ai",
  [string]$Core = "C:\Users\gubbi\jarvis_core",
  [string]$BaseBranch = "autopilot_main",
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Repo)) { throw "Repo findes ikke: $Repo" }
if (-not (Test-Path $Core)) { New-Item -ItemType Directory -Force -Path $Core | Out-Null }

Push-Location $Repo
try {
  git fetch --all --prune | Out-Null
  git checkout $BaseBranch | Out-Null
  git pull --ff-only origin $BaseBranch | Out-Null

  $marker = Join-Path $Repo ".last_promoted"
  if (Test-Path $marker) {
    $raw  = Get-Content $marker -Raw
    $hash = ([regex]::Match($raw, '^[0-9a-f]{7,40}', 'IgnoreCase')).Value
    $last = if ($hash) { $hash } else { git rev-list --max-parents=0 HEAD | Select-Object -First 1 }
  } else {
    $last = git rev-list --max-parents=0 HEAD | Select-Object -First 1
  }

  $head = (git rev-parse HEAD).Trim()

  $files = ((git diff --name-only $last $head) -split "`n") |
           ? { $_ } |
           ? { $_ -notmatch '(^\.git|^\.github|^ai_inbox|^ai_tasks|\.md$)' } |
           ? { $_ -notmatch '(^|\\)big\.bin$' }

  if (-not $files) {
    Write-Host "Ingen promoverbare ændringer."
    $head | Set-Content -Encoding ascii $marker
    return
  }

  foreach ($rel in $files) {
    $src = Join-Path $Repo $rel
    $dst = Join-Path $Core $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    if ($DryRun) {
      Write-Host "[DRY RUN] Would promote: $rel"
    } else {
      Copy-Item -LiteralPath $src -Destination $dst -Force
      Write-Host "Promoted: $rel"
    }
  }

  if ($DryRun) { Write-Host "Dry run complete." }
  else {
    $head | Set-Content -Encoding ascii $marker
    Write-Host "Promotion complete → $Core"
  }
}
finally { Pop-Location }
