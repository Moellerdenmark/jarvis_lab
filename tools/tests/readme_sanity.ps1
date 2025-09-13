$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$readme   = Join-Path $repoRoot 'README.md'
if (-not (Test-Path $readme)) { Write-Host "README.md mangler"; exit 1 }
$txt = Get-Content -Raw -Encoding UTF8 $readme

$ok = $true
if ($txt -notmatch 'Jarvis self-build\s*✓') { Write-Host "Mangler: 'Jarvis self-build ✓'"; $ok = $false }
if ($txt -notmatch 'PS-only pipeline\s*✓✓') { Write-Host "Mangler: 'PS-only pipeline ✓✓'"; $ok = $false }
$fences = [regex]::Matches($txt,'```').Count
if (($fences % 2) -ne 0) { Write-Host "Ubalancerede code fences (```): $fences"; $ok = $false }

if ($ok) { Write-Host "README sanity: OK"; exit 0 } else { exit 1 }
