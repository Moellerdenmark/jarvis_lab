param(
  [Parameter(Mandatory=$true)][string]$Prompt,
  [string]$Model   = "qwen2.5:3b-instruct",
  [string]$OutFile = "C:\Users\gubbi\jarvis_core\out\listen\last_reply.txt",
  [string]$Endpoint = ""   # tom = prøv 127.0.0.1 -> localhost
)

$ErrorActionPreference = "Stop"

# Slå proxy fra for lokale kald
$env:HTTP_PROXY=""; $env:http_proxy=""; $env:HTTPS_PROXY=""; $env:https_proxy=""

$endpoints = @()
if ($Endpoint -and $Endpoint.Trim()) { $endpoints += $Endpoint.TrimEnd('/') }
$endpoints += @("http://127.0.0.1:11434","http://localhost:11434") | Select-Object -Unique

function Test-API([string]$base){
  try { Invoke-WebRequest -Uri "$base/api/tags" -TimeoutSec 3 | Out-Null; return $true }
  catch { return $false }
}

# vælg første der svarer
$baseUrl = $null
foreach($e in $endpoints){ if (Test-API $e) { $baseUrl = $e; break } }
if (-not $baseUrl) { Write-Host "[AI] FEJL: Ingen endpoints svarede: $($endpoints -join ', ')" -ForegroundColor Red; throw "Ollama API utilgængelig" }

$system = @"
Du er Jarvis. Svar på dansk, naturligt og kort (2–4 sætninger).
Gentag ikke brugerens tekst ordret. Vær hjælpsom og konkret.
"@

$payload = @{
  model  = $Model
  prompt = "$system`nBruger: $Prompt`nJarvis:"
  stream = $false
} | ConvertTo-Json -Depth 6

Write-Host "[AI] Sender prompt til $baseUrl med model $Model" -ForegroundColor Cyan
try {
  $resp = Invoke-WebRequest -Uri "$baseUrl/api/generate" -Method POST -Body $payload -ContentType 'application/json' -TimeoutSec 180
  $data = $resp.Content | ConvertFrom-Json
  $text = $data.response
  if ([string]::IsNullOrWhiteSpace($text)) { throw "Tomt svar fra modellen." }
  New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
  Set-Content -Path $OutFile -Value $text -Encoding UTF8
  Write-Host "[AI] OK ($Model) → $OutFile" -ForegroundColor Green
  $text
} catch {
  Write-Host "[AI] FEJL ved kald til $baseUrl/api/generate" -ForegroundColor Red
  Write-Host "      $($_.Exception.Message)" -ForegroundColor Yellow
  if ($_.Exception.Response) {
    try { Write-Host "      BODY: " ((New-Object IO.StreamReader $_.Exception.Response.GetResponseStream()).ReadToEnd()) }
    catch {}
  }
  throw
}
