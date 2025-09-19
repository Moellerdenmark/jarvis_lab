param([Parameter(Mandatory=$true)][string]$Prompt)

$ErrorActionPreference = "Stop"
function Use-Ollama {
  param([string]$Model,[string]$Prompt)
  $uri  = "http://127.0.0.1:11434/api/generate"
  $body = @{ model=$Model; prompt=$Prompt; stream=$false } | ConvertTo-Json -Depth 5
  $r = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json' -TimeoutSec 60
  return ($r.response | Out-String).Trim()
}

try {
  $model = if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { 'qwen2.5:3b-instruct' }
  $reply = Use-Ollama -Model $model -Prompt $Prompt
  if ([string]::IsNullOrWhiteSpace($reply)) { throw "Tomt svar." }
  $reply
} catch {
  # kort, stille fallback
  if ($Prompt -match 'hej\s+jarvis') { "Hej! Hvad kan jeg hjælpe med?" } else { "Jeg hørte: $Prompt" }
}
