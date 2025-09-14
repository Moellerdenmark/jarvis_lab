param(
  [string]$Repo  = (Resolve-Path "$PSScriptRoot\..\..").Path,
  [string]$Title = "custom_task",
  [string]$Body  = "Plan: Beskriv hvad der skal ske."
)
$ErrorActionPreference = "Stop"
$inbox = Join-Path $Repo 'ai_inbox'
New-Item -ItemType Directory -Force -Path $inbox | Out-Null
$slug = ($Title -replace '[^\w\-]+','_').Trim('_'); if (-not $slug) { $slug = 'task' }
$now  = Get-Date -Format 'yyyyMMdd_HHmmss'
$nums = Get-ChildItem $inbox -File -Filter '*.md' -EA SilentlyContinue |
  ForEach-Object { if ($_.Name -match '^(?<n>\d{3})_'){ [int]$Matches['n'] } }
$max  = if ($nums){ ($nums | Measure-Object -Maximum).Maximum } else { 0 }
$next = '{0:D3}' -f ($max + 1)
$name = "{0}_{1}_{2}.md" -f $next, $slug, $now
$path = Join-Path $inbox $name
@"
$name
------------------------------------------------------------

$Body
"@ | Set-Content -Encoding utf8NoBOM -LiteralPath $path
Write-Host "Created: $path"
