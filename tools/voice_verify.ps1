# PATH: tools\voice_verify.ps1
param(
  [Parameter(Mandatory=$true)][string]$Wav,
  [double]$MinScore = 0.85
)
$ErrorActionPreference = "Stop"
$tools  = Split-Path -Parent $MyInvocation.MyCommand.Path
$root   = Split-Path -Parent $tools
$profRoot = Join-Path $root 'profiles\speakers'
if (-not (Test-Path $profRoot)) { return [pscustomobject]@{ ok=$false; reason='no-profiles' } }
# Python
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
if (-not $py) { return [pscustomobject]@{ ok=$false; reason='no-python' } }
# Embedding
$json = & $py (Join-Path $tools 'spk_embed.py') $Wav
try { $obj = $json | ConvertFrom-Json } catch { return [pscustomobject]@{ ok=$false; reason='bad-json'; detail=$json } }
if ($obj.error) { return [pscustomobject]@{ ok=$false; reason='embed-error'; detail=$obj.error } }
$e = [double[]]$obj.embedding
function Cos([double[]]$a,[double[]]$b){ $s=0.0; for($i=0;$i -lt $a.Count;$i++){ $s+=$a[$i]*$b[$i] }; [double]$s }
$best=$null
Get-ChildItem $profRoot -Directory | % {
  $j = Join-Path $_.FullName 'voice.json'
  if (Test-Path $j) {
    $p = Get-Content $j -Raw | ConvertFrom-Json
    $score = Cos $e ([double[]]$p.mean)
    if (-not $best -or $score -gt $best.score) { $best = [pscustomobject]@{ name=$p.name; score=$score; path=$j } }
  }
}
if (-not $best) { return [pscustomobject]@{ ok=$false; reason='no-profiles' } }
[pscustomobject]@{ ok=($best.score -ge $MinScore); name=$best.name; score=[math]::Round($best.score,3); path=$best.path }
