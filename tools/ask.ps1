param(
  [Parameter(Mandatory=$true)][string]$Text,
  [string]$Model = "llama3.2:3b"
)

$ErrorActionPreference = "Stop"
$OllamaUrl = "http://localhost:11434/api/generate"

$sys = @"
Du er Jarvis, en dansk assistent. 
Svar altid kort, klart og på flydende dansk.
"@

$body = @{
  model = $Model
  prompt = "$sys`nBruger: $Text`nJarvis:"
  stream = $false
} | ConvertTo-Json -Depth 5

try {
  $resp = Invoke-RestMethod -Uri $OllamaUrl -Method Post -Body $body -ContentType "application/json"
  $reply = ($resp.response ?? "").Trim()
} catch {
  $reply = "Jeg kunne ikke få svar fra modellen."
}

Write-Host "🤖 $reply" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "say.ps1") -Text $reply
