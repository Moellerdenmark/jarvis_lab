param(
  [string]$InputText,
  [string]$InputWav,
  [string]$OutWav,
  [switch]$NoPlay
)
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cfgPath  = Join-Path $repoRoot "tools\models.psd1"
$cfg = @{}; if (Test-Path $cfgPath) { $cfg = Import-PowerShellDataFile $cfgPath }

$LlmUrl   = $cfg.LlmUrl   ; if (-not $LlmUrl)   { $LlmUrl   = "http://127.0.0.1:11434" }
$LlmModel = $cfg.LlmModel ; if (-not $LlmModel) { $LlmModel = "llama3.1:8b" }
$Whisper  = $cfg.WhisperUrl
$piperExe = $cfg.PiperExe
$piperVoice = $cfg.PiperVoice
$outDir   = Join-Path $repoRoot ($cfg.OutDir ? $cfg.OutDir : "out\\voice")
New-Item -ItemType Directory -Force $outDir | Out-Null

# STT (valgfri WAV) / tekstinput
if (-not $InputText) {
  if ($InputWav) {
    try {
      if (-not $Whisper) { throw "WhisperUrl not configured" }
      $form = @{ file = Get-Item $InputWav }
      $resp = $null
      try {
        $resp = Invoke-RestMethod -Uri ($Whisper.TrimEnd('/') + '/transcribe') -Method Post -Form $form -TimeoutSec 30
      } catch {}
      $InputText = if ($resp -and $resp.text) { [string]$resp.text } else { "<voice input could not be transcribed>" }
    } catch {
      $InputText = "<voice input not available: $($_.Exception.Message)>"
    }
  } else {
    $InputText = Read-Host "Sig/skriv til Jarvis"
  }
}

# LLM (Ollama REST /api/generate)
$reply = $null
try {
  $body = @{ model = $LlmModel; prompt = $InputText; stream = $false }
  $resp = Invoke-RestMethod -Uri ($LlmUrl.TrimEnd('/') + '/api/generate') -Method Post `
    -Body ($body | ConvertTo-Json -Depth 6) -ContentType 'application/json' -TimeoutSec 120
  $reply = [string]$resp.response
} catch {
  $reply = "Jeg kunne ikke nå LLM'en ($LlmUrl): $($_.Exception.Message)."
}

# OutWav sti
if (-not $OutWav) { $OutWav = Join-Path $outDir ("jarvis_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".wav") }

# TTS: Piper CLI -> fallback: lille tone-WAV
function New-SineWaveWav([string]$Path,[int]$ms=800,[int]$hz=440,[int]$rate=16000){
  $samples = [int]($rate * ($ms/1000.0))
  $blockAlign = 2; $byteRate = $rate * $blockAlign; $subchunk2 = $samples * $blockAlign; $chunkSize = 36 + $subchunk2
  $bw = New-Object System.IO.BinaryWriter([System.IO.File]::Open($Path, [System.IO.FileMode]::Create))
  $w = { param($s) $bw.Write([System.Text.Encoding]::ASCII.GetBytes($s)) }
  & $w 'RIFF'; $bw.Write([int]$chunkSize); & $w 'WAVE'
  & $w 'fmt '; $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
  $bw.Write([int]$rate); $bw.Write([int]$byteRate); $bw.Write([int16]$blockAlign); $bw.Write([int16]16)
  & $w 'data'; $bw.Write([int]$subchunk2)
  for($i=0;$i -lt $samples;$i++){ $t = 2*[Math]::PI * $hz * ($i/[double]$rate); $bw.Write([int16][Math]::Round([Math]::Sin($t)*3000)) }
  $bw.Close()
}

$ok = $false
if (Test-Path $piperExe) {
  try {
    $cmd = "& `"$piperExe`" --model $piperVoice --text ""$reply"" --output_file `"$OutWav`""
    Invoke-Expression -Command $cmd
    $ok = $true
  } catch {
    Write-Host "Piper ikke tilgængelig – genererer tone som placeholder." -ForegroundColor Yellow
    New-SineWaveWav -Path $OutWav
    $ok = $true
  }
} else {
  throw "PiperExe not found. Please set the correct path in tools/models.psd1."
}

if (-not (Test-Path $OutWav)) { throw "Kunne ikke lave WAV: $OutWav" }
Write-Host "Reply:  $reply"
Write-Host "OutWav: $OutWav"

if (-not $NoPlay) {
  try { (New-Object System.Media.SoundPlayer $OutWav).PlaySync() } catch {}
}
