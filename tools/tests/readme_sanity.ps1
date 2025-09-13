$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$readme   = Join-Path $repoRoot 'README.md'
if (-not (Test-Path $readme)) { throw 'README.md mangler' }

$txt    = Get-Content -Raw -Encoding UTF8 $readme
$check  = [char]0x2713
$double = "$check$check"

$errors = @()
if ($txt -notmatch "Jarvis\s+self-build\s*$check") { $errors += "Mangler: 'Jarvis self-build $check'" }
if ($txt -notmatch "PS-only\s+pipeline\s*$double") { $errors += "Mangler: 'PS-only pipeline $double'" }

$fences = ([regex]::Matches($txt,'```')).Count
if (($fences % 2) -ne 0) { $errors += "Ubalancerede code fences (```): $fences" }

if ($errors.Count) {
  $errors | ForEach-Object { Write-Host $_ }
  throw 'README sanity failed'
} else {
  Write-Host 'README sanity: OK'
}
