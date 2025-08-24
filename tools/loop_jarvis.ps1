param(
  [string]$Root         = "C:\Users\gubbi\jarvis_core",
  [string]$AiCmd        = "C:\Users\gubbi\jarvis_core\tools\ai.ps1",
  [string]$TtsCmd       = "C:\Users\gubbi\jarvis_core\tools\speak.ps1",
  [string]$SttCmd       = "C:\Users\gubbi\jarvis_core\tools\stt.ps1",
  [string]$Voice        = "Jarvis",
  [int]$Rate            = 0,
  [int]$Volume          = 100,
  [int]$AiTimeoutSec    = 15,
  [int]$TtsTimeoutSec   = 10,
  [int]$SttTimeoutSec   = 12,
  [switch]$Test
)

# Tving UTF-8 også når scriptet køres selvstændigt
try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Paths ---
$SttFile = Join-Path $Root "out\listen\last_stt.txt"

# --- Helpers ---
function Get-PromptFromFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  for ($i=0; $i -lt 3; $i++) {
    try { return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim() }
    catch { Start-Sleep -Milliseconds 80 }
  }
  return $null
}

function Normalize-Text {
  param([string]$Text)
  if (-not $Text) { return "" }
  $t = $Text -replace '[\p{Ps}\p{Pe}"“”„‚‘’»«]', ''
  $t = ($t -replace '\s+', ' ').Trim()
  return $t
}

# Wakeword regex
$rx1 = [regex]::new('(?i)\b(?:hej|hey)\s+jarvis\b[ \t,.:;\-\u2013\u2014]*?(.*\S)?\s*$')
$rx2 = [regex]::new('(?i)^\s*jarvis\b[ \t,.:;\-\u2013\u2014]*?(.*\S)?\s*$')
$rx3 = [regex]::new('(?i)^\s*jarvis\s*[?.!]*\s*$')

function Extract-Message {
  param([string]$Prompt)
  $norm = Normalize-Text $Prompt
  if ($rx1.IsMatch($norm)) { return ,($true, $rx1.Match($norm).Groups[1].Value) }
  if ($rx2.IsMatch($norm)) { return ,($true, $rx2.Match($norm).Groups[1].Value) }
  if ($rx3.IsMatch($norm)) { return ,($true, "") }   # kun wakeword
  return ,($false, $null)
}

function Invoke-WithTimeout {
  param([scriptblock]$Script, [int]$TimeoutSec = 10)
  $job = Start-Job -ScriptBlock $Script
  try {
    $ok = Wait-Job -Id $job.Id -Timeout $TimeoutSec
    if (-not $ok) {
      Stop-Job -Id $job.Id -Force | Out-Null
      Remove-Job -Id $job.Id -Force | Out-Null
      return ,($false, $null, "timeout")
    }
    $out = Receive-Job -Id $job.Id -ErrorAction Stop
    Remove-Job -Id $job.Id -Force | Out-Null
    return ,($true, $out, $null)
  } catch {
    try { Remove-Job -Id $job.Id -Force | Out-Null } catch {}
    return ,($false, $null, $_.Exception.Message)
  }
}

function Speak-Safe {
  param([string]$Text, [string]$Voice, [int]$Rate, [int]$Volume, [int]$TimeoutSec)
  if ($Test -or -not (Test-Path $TtsCmd)) {
    Write-Host "[TTS] (dummy) $Text" -ForegroundColor DarkGreen
    return $true
  }
  $sb = { & $using:TtsCmd -Text $using:Text -Voice $using:Voice -Rate $using:Rate -Volume $using:Volume }
  $ok,$out,$err = Invoke-WithTimeout -Script $sb -TimeoutSec $TimeoutSec
  if (-not $ok) { Write-Host "[TTS] Fejl/timeout: $err" -ForegroundColor Red; return $false }
  Write-Host "[TTS] Læst op." -ForegroundColor DarkGreen
  return $true
}

function AskAI-Safe {
  param([string]$Msg, [int]$TimeoutSec)
  if ($Test -or -not (Test-Path $AiCmd)) {
    return "Okay - jeg hørte: $Msg"
  }
  $sb = { & $using:AiCmd -Prompt $using:Msg }
  $ok,$out,$err = Invoke-WithTimeout -Script $sb -TimeoutSec $TimeoutSec
  if (-not $ok) { Write-Host "[AI] Fejl/timeout: $err" -ForegroundColor Red; return $null }
  return ($out | Out-String).Trim()
}

function Get-NextUtterance {
  param([int]$TimeoutSec = 8)
  if (-not (Test-Path $SttCmd)) {
    Write-Host "[STT] Sti findes ikke: $SttCmd" -ForegroundColor Red
    return $null
  }
  $sb = { & $using:SttCmd }
  $ok,$out,$err = Invoke-WithTimeout -Script $sb -TimeoutSec $TimeoutSec
  if (-not $ok) {
    Write-Host "[STT] Fejl/timeout: $err" -ForegroundColor Red
    return $null
  }
  $raw = ($out | Out-String).Trim()
  if (-not $raw) { return $null }
  # tag tekst efter sidste ']'
  $parts = $raw -split '\]'
  $last  = $parts[-1].Trim()
  if (-not $last) { return $null }
  return $last
}

# --- Self-test ---
if ($Test) {
  Write-Host "[TEST] Kører i testtilstand (uden STT-fil)" -ForegroundColor Yellow
  $samples = @(
    "Hej Jarvis",
    "Hey Jarvis - status?",
    "Jarvis, tænd lyset i garagen",
    "jarvis?",
    "intet wakeword her",
    "Hej Jarvis kan du sige hej på dansk"
  )
  foreach($p in $samples){
    Write-Host "-----" -ForegroundColor DarkGray
    Write-Host "[TEST] Prompt rå: $p" -ForegroundColor DarkYellow
    $found,$msg = Extract-Message $p
    if ($found) {
      try { [console]::Beep(1200,120) } catch {}
      if ([string]::IsNullOrWhiteSpace($msg)) {
        Speak-Safe -Text "Jeg lytter..." -Voice $Voice -Rate $Rate -Volume $Volume -TimeoutSec $TtsTimeoutSec | Out-Null
        Write-Host "[Jarvis] Kun wakeword – starter STT..." -ForegroundColor DarkGreen
        $next = Get-NextUtterance -TimeoutSec $SttTimeoutSec
        if ($next) {
          Write-Host "[Jarvis] Næste ytring: $next" -ForegroundColor Cyan
          $reply = AskAI-Safe -Msg $next -TimeoutSec $AiTimeoutSec
          if (-not $reply) { $reply = "Jeg er her." }
          Speak-Safe -Text $reply -Voice $Voice -Rate $Rate -Volume $Volume -TimeoutSec $TtsTimeoutSec | Out-Null
        } else {
          Write-Host "[STT] Ingen tale opfanget." -ForegroundColor Yellow
        }
        continue
      }
      Write-Host "[Jarvis] Aktiveret med: $msg" -ForegroundColor Cyan
      $reply = AskAI-Safe -Msg $msg -TimeoutSec $AiTimeoutSec
      if (-not $reply) { $reply = "Jeg er her." }
      Speak-Safe -Text $reply -Voice $Voice -Rate $Rate -Volume $Volume -TimeoutSec $TtsTimeoutSec | Out-Null
    } else {
      Write-Host "[Jarvis] Ingen wakeword. Ignorerer." -ForegroundColor DarkGray
    }
  }
  Write-Host "[TEST] Færdig." -ForegroundColor Green
  exit 0
}

# --- Normal loop ---
$lastWrite = $null
$lastSeen  = $null
if (-not (Test-Path $SttFile)) {
  Write-Host "[INIT] STT-fil findes ikke endnu: $SttFile (venter...)" -ForegroundColor Yellow
}
Write-Host "[RUN] Loop start. Ctrl+C for stop." -ForegroundColor Green

while ($true) {
  try {
    if (-not (Test-Path $SttFile)) { Start-Sleep -Milliseconds 300; continue }

    $fi = Get-Item -LiteralPath $SttFile -ErrorAction SilentlyContinue
    if (-not $fi) { Start-Sleep -Milliseconds 150; continue }

    $w = $fi.LastWriteTimeUtc
    if ($lastWrite -and $w -eq $lastWrite) { Start-Sleep -Milliseconds 120; continue }

    $raw = Get-PromptFromFile -Path $SttFile
    $lastWrite = $w

    if (-not $raw) { Start-Sleep -Milliseconds 120; continue }
    if ($raw -eq $lastSeen) { Start-Sleep -Milliseconds 80; continue }
    $lastSeen = $raw

    Write-Host "[DBG] Raw: $raw" -ForegroundColor DarkYellow

    $found,$msg = Extract-Message $raw
    if ($found) {
      try { [console]::Beep(1200,120) } catch {}
      if ([string]::IsNullOrWhiteSpace($msg)) {
        Speak-Safe -Text "Jeg lytter..." -Voice $Voice -Rate $Rate -Volume $Volume -TimeoutSec $TtsTimeoutSec | Out-Null
        Write-Host "[Jarvis] Wakeword fundet. Starter STT for næste ytring..." -ForegroundColor DarkGreen
        $next = Get-NextUtterance -TimeoutSec $SttTimeoutSec
        if (-not $next) { Write-Host "[STT] Ingen tale opfanget." -ForegroundColor Yellow; continue }
        Write-Host "[Jarvis] Næste ytring: $next" -ForegroundColor Cyan
        $msg = $next
      } else {
        Write-Host "[Jarvis] Aktiveret med: $msg" -ForegroundColor Cyan
      }

      $reply = AskAI-Safe -Msg $msg -TimeoutSec $AiTimeoutSec
      if (-not $reply) { $reply = "Jeg er her." }
      Speak-Safe -Text $reply -Voice $Voice -Rate $Rate -Volume $Volume -TimeoutSec $TtsTimeoutSec | Out-Null
    }
    else {
      Write-Host "[Jarvis] Ingen wakeword. Ignorerer." -ForegroundColor DarkGray
    }

    Start-Sleep -Milliseconds 120
  }
  catch {
    Write-Host "[Loop] Uventet fejl: $($_.Exception.Message)" -ForegroundColor Red
    Start-Sleep -Milliseconds 400
  }
}
