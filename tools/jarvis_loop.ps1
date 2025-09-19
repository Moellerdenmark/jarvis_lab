param(
  [int]$DeviceID = 1,                 # 1 = MME headset hos dig, 12 = WASAPI headset
  [int]$Duration = 6,                 # sek pr. optagelse
  [string]$WhisperModel = "small",    # "base","small","medium"
  [string]$Model = "llama3.2:3b",     # hurtig på CPU. Brug "llama3.1:8b" for mere kapacitet
  [string]$Lang = "da"                # dansk STT
)

$ErrorActionPreference = "Stop"
chcp 65001 > $null
$env:PYTHONIOENCODING = "utf-8"

# --- Stier ---
$PYTHON = Join-Path $PSScriptRoot "..\.venv\Scripts\python.exe" | Resolve-Path
$REC    = Join-Path $PSScriptRoot "record6s.py"
$SAY    = Join-Path $PSScriptRoot "say.ps1"
$LOGDIR = Join-Path $ROOT "logs"
$WAV    = Join-Path $OUT  "jarvis_in.wav"
$BOOST  = Join-Path $OUT  "jarvis_in_boosted.wav"
$OllamaUrl = "http://localhost:11434/api/generate"

if (-not (Test-Path $REC)) { throw "Mangler: $REC" }
if (-not (Test-Path $SAY)) { throw "Mangler: $SAY" }
if (-not (Test-Path $LOGDIR)) { New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null }
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  throw "ffmpeg mangler i PATH"
}

# --- systemprompt på dansk ---
$SystemPrompt = @"
Du er Jarvis, en dansk assistent.
Svar altid kort, klart og på flydende dansk.
Hold en venlig og naturlig tone. Brug punktummer.
"@

# --- helper: optag + boost + transskriber til dansk tekst ---
function Get-Text([int]$dev,[int]$secs,[string]$lang,[string]$wmodel){
  # 1) optag til fast fil ($WAV)
  if (Test-Path $WAV) { Remove-Item $WAV -Force -ErrorAction SilentlyContinue }
  & $PYTHON $REC $WAV $dev 16000 $secs | Out-Host
  if (-not (Test-Path $WAV)) { return "" }

  # 2) boost/clean til fast fil ($BOOST)
  if (Test-Path $BOOST) { Remove-Item $BOOST -Force -ErrorAction SilentlyContinue }
  ffmpeg -y -i "$WAV" -af "highpass=f=120, lowpass=f=7000, dynaudnorm=f=200:g=15, volume=8dB" "$BOOST" | Out-Null
  if (-not (Test-Path $BOOST)) { return "" }

  # 3) whisper -> .txt ved siden af $BOOST
  $txtFile = "$BOOST.txt"
  if (Test-Path $txtFile) { Remove-Item $txtFile -Force -ErrorAction SilentlyContinue }
  $args = @("$BOOST","--model",$wmodel,"--language",$lang,"--fp16","False","--task","transcribe","--temperature","0","--best_of","1","--output_format","txt")
  & $PYTHON -m whisper @args | Out-Null
  if (Test-Path $txtFile) { 
    return (Get-Content $txtFile -Raw).Trim()
  }
  return ""
}

# --- helper: sig svaret højt ---
function SpeakDa([string]$text){
  if (-not $text) { return }
  if ($text -notmatch "[\.\!\?]$") { $text += "." }
  & $SAY -Text $text
}

Write-Host "🎙 Jarvis loop klar. Sig 'stop' eller 'slut' for at afslutte." -ForegroundColor Cyan

while ($true) {
  Write-Host ""
  Write-Host "🎤 Tal nu (optager $Duration s)..." -ForegroundColor Yellow
  [console]::Beep(750,120)

  $txt = Get-Text -dev $DeviceID -secs $Duration -lang $Lang -wmodel $WhisperModel

  if (-not $txt) {
    Write-Host "🙈 Ingen tekst opfanget. Prøver igen..." -ForegroundColor DarkYellow
    continue
  }

  Write-Host "🗣 Du: $txt" -ForegroundColor Green

  # stopord
  if ($txt -match '^\s*(stop|slut|farvel)\s*$') {
    SpeakDa "Okay, jeg stopper nu. Hej hej!"
    break
  }

  # --- Intent router: prøv skills før LLM ---
  $skillsFile = Join-Path $PSScriptRoot "skills.yml"
  $handled = $false
  if (Test-Path $skillsFile) {
    try {
      if (-not (Get-Module -ListAvailable PowerShellYAML)) {
        try { Import-Module PowerShellYAML -ErrorAction Stop } catch {}
      } else { Import-Module PowerShellYAML -ErrorAction SilentlyContinue }
      if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
        $skills = ConvertFrom-Yaml (Get-Content $skillsFile -Raw)
        foreach ($s in $skills) {
          if ($txt -match $s.match) {
            Write-Host "⚙️ Kører skill: $($s.name)" -ForegroundColor Magenta
            Invoke-Expression $s.run
            $handled = $true
            break
          }
        }
      }
    } catch {}
  }
  if ($handled) { continue }

  # --- LLM kald (Ollama) ---
  $prompt = "$SystemPrompt`nBruger: $txt`nJarvis:"
  $body = @{ model=$Model; prompt=$prompt; stream=$false } | ConvertTo-Json -Depth 5
  try {
    $resp = Invoke-RestMethod -Uri $OllamaUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
    $reply = ($resp.response ?? "").Trim()
  } catch {
    $reply = "Jeg kunne ikke få svar fra modellen."
  }

  Write-Host "🤖 Jarvis: $reply" -ForegroundColor Cyan
  SpeakDa $reply

  # --- Log til fil ---
  if (-not (Test-Path $LOGDIR)) { New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null }
  $line = "{0:u} | DU: {1} | JARVIS: {2}" -f (Get-Date), $txt, ($reply -replace '\r?\n',' ')
  Add-Content -Path (Join-Path $LOGDIR "conversation.log") -Value $line
}

