param(
  [string]$SttCmd,
  [string]$TtsCmd,
  [string]$DeviceName,
  [int]$Seconds = 6
)
$ErrorActionPreference = "Stop"

$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $tools

if (-not $SttCmd) { $SttCmd = Join-Path $tools "stt_mic_wrapper.ps1" }
if (-not $TtsCmd) { $TtsCmd = Join-Path $tools "speak.ps1" }

$llmScript = Join-Path $tools "llm.ps1"
if (-not (Test-Path $llmScript)) { $llmScript = Join-Path $root "tools\llm.ps1" }
if (-not (Test-Path $llmScript)) { throw "Kan ikke finde llm.ps1" }

# diag (en gang pr start)
try{
  $logDir = Join-Path $root "logs"
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  ("tools: {0}`nroot: {1}`nSttCmd: {2}`nTtsCmd: {3}`nllm: {4}" -f $tools,$root,$SttCmd,$TtsCmd,$llmScript) |
    Out-File (Join-Path $logDir 'diag.txt') -Append -Encoding UTF8
}catch{}

while ($true) {
  try {
    # 1) STT
    if ($DeviceName) { $sttOut = & $SttCmd -DeviceName $DeviceName -Seconds $Seconds }
    else              { $sttOut = & $SttCmd -Seconds $Seconds }

    if (-not $sttOut) { Start-Sleep -Milliseconds 150; continue }
    $prompt = ($sttOut | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($prompt)) { continue }

    # 2) LLM -> 3) TTS
    $reply = & $llmScript -Prompt ("Svar venligst på dansk: " + $prompt) 2>$null
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "Okay." }
    & $TtsCmd -Text $reply $11 $11
  }
  catch {
    $logDir = Join-Path $root "logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    ("[{0}] loop_hotword.ps1 FEJL: {1}" -f (Get-Date), $_.Exception.Message) |
      Out-File -FilePath (Join-Path $logDir "errors.log") -Append -Encoding UTF8
    Start-Sleep -Seconds 1
  }
  Start-Sleep -Milliseconds 150
}





