param(
  [ValidateSet("chatgpt","chatgpt_read")]
  [string]$Provider,
  [string]$Prompt,
  [int]$TimeoutMs = 25000,

  # Valgmuligheder
  [string]$Model = $env:OLLAMA_MODEL,
  [string]$Session = "default",
  [switch]$Reset,
  [string]$System = "Du er Jarvis. Svar kort, præcist og på dansk.",
  [int]$KeepLast = 12
)

$ErrorActionPreference = "Stop"
$root    = "C:\\Users\\gubbi\\jarvis_lab"
$outDir  = Join-Path $root "out"
$sesDir  = Join-Path $outDir "sessions"
$outFile = Join-Path $outDir "chatgpt_last.txt"
$sesFile = Join-Path $sesDir ("{0}.json" -f $Session)

if (-not $env:OLLAMA_HOST)  { $env:OLLAMA_HOST  = 'http://127.0.0.1:11434' }
if (-not $env:OLLAMA_MODEL) { $env:OLLAMA_MODEL = 'qwen2.5:3b-instruct' }
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = $env:OLLAMA_MODEL }

New-Item -ItemType Directory -Force -Path $outDir,$sesDir | Out-Null

function Resolve-Model([string]$Requested){
  try {
    $tags = Invoke-RestMethod "$($env:OLLAMA_HOST)/api/tags" -Method Get -TimeoutSec 5
    $installed = @($tags.models | ForEach-Object { $_.name })
  } catch {
    # Kan ikke hente tags → brug Requested som er
    return $Requested
  }
  if ($installed -contains $Requested) { return $Requested }

  # Foretræk instruct-varianter først, ellers første bedste installerede
  $pref = @(
    'qwen2.5:3b-instruct','qwen2.5:7b-instruct',
    'llama3.1:8b-instruct','llama3.1:8b',
    'llama3.2:3b','qwen2.5:7b'
  )
  foreach($p in $pref){ if ($installed -contains $p){ Write-Host "[MODEL] '$Requested' ikke fundet → bruger '$p'." -ForegroundColor Yellow; return $p } }
  if ($installed.Count -gt 0){ Write-Host "[MODEL] '$Requested' ikke fundet → bruger '$($installed[0])'." -ForegroundColor Yellow; return $installed[0] }
  throw "Ingen modeller installeret. Kør fx:  ollama pull qwen2.5:3b-instruct"
}

function Get-SessionMessages {
  if ($Reset -and (Test-Path $sesFile)) { Remove-Item -Force $sesFile }
  if (Test-Path $sesFile) {
    try { return Get-Content $sesFile -Raw | ConvertFrom-Json } catch { @() }
  }
  return @()
}
function Save-SessionMessages($msgs) {
  ($msgs | ConvertTo-Json -Depth 20) | Set-Content -Path $sesFile -Encoding UTF8
}
function Build-PromptFromMessages {
  param([Array]$Messages)
  $sb = New-Object System.Text.StringBuilder
  foreach ($m in $Messages) {
    $role = if ($m.role) { [string]$m.role } else { 'user' }
    $label = switch ($role) { 'system' {'System'} 'assistant' {'Assistant'} default {'User'} }
    $content = [string]$m.content
    [void]$sb.AppendLine( ('{0}: {1}' -f $label, $content) )
  }
  [void]$sb.Append('Assistant: ')
  $sb.ToString()
}

function Invoke-OllamaChatSmart {
  param([string]$Model,[Array]$Messages,[int]$TimeoutMs)
  $base = $env:OLLAMA_HOST
  $headers = @{ 'Content-Type'='application/json' }

  # 1) /api/chat (nye Ollama)
  $chatBody = @{ model=$Model; stream=$false; messages=$Messages } | ConvertTo-Json -Depth 20
  $useGenerate = $false
  try {
    $r = Invoke-RestMethod -Uri "$base/api/chat" -Method Post -Headers $headers -Body $chatBody -TimeoutSec ([Math]::Ceiling($TimeoutMs/1000))
    if ($r -and $r.message -and $r.message.content) { return $r.message.content } else { $useGenerate = $true }
  } catch { $useGenerate = $true }

  # 2) /api/generate (fallback, findes altid)
  if ($useGenerate) {
    $prompt = Build-PromptFromMessages -Messages $Messages
    $genBody = @{ model=$Model; stream=$false; prompt=$prompt } | ConvertTo-Json -Depth 20
    $r2 = Invoke-RestMethod -Uri "$base/api/generate" -Method Post -Headers $headers -Body $genBody -TimeoutSec ([Math]::Ceiling($TimeoutMs/1000))
    if ($r2 -and $r2.response) { return $r2.response }
    throw "Ollama /api/generate returnerede ingen 'response'."
  }
}

switch ($Provider) {
  'chatgpt' {
    if (-not $Prompt) { throw "Mangler -Prompt" }
    $Model = Resolve-Model $Model

    $history = @(Get-SessionMessages)
    if ($history.Count -gt $KeepLast) { $history = $history[($history.Count-$KeepLast)..($history.Count-1)] }

    $msgs = @()
    if ($System) { $msgs += @{ role='system'; content=$System } }
    $msgs += $history
    $msgs += @{ role='user'; content=$Prompt }

    $ans = Invoke-OllamaChatSmart -Model $Model -Messages $msgs -TimeoutMs $TimeoutMs

    $history += @{ role='user'; content=$Prompt }
    $history += @{ role='assistant'; content=$ans }
    Save-SessionMessages $history

    $ans | Set-Content -Path $outFile -Encoding UTF8
    Write-Output $ans
  }
  'chatgpt_read' {
    if (Test-Path $outFile) { Get-Content $outFile -Raw } else { "" }
  }
}

