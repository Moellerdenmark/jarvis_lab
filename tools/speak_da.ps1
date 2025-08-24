param(
  [Parameter(Mandatory=$true)]
  [string]$Text,

  # Gem også til WAV (valgfrit)
  [string]$OutPath,

  # Afspil når færdig
  [switch]$Play,

  # Tving brug af SAPI i stedet for Piper
  [switch]$ForceSapi
)

$ErrorActionPreference = "Stop"

# --- KONFIG ---
$Root        = "C:\Users\gubbi\jarvis_core"
$PiperExe    = Join-Path $Root "piper\bin\piper\piper.exe"   # typisk placering fra din opsætning
if (-not (Test-Path $PiperExe)) { $PiperExe = Join-Path $Root "piper\bin\piper.exe" } # alternativ
$PiperModels = Join-Path $Root "piper\models"

# Find en dansk Piper-model automatisk (da_ / da-DK)
$PiperOnnx = $null
$PiperJson = $null
if (Test-Path $PiperModels) {
  $cand = Get-ChildItem $PiperModels -Recurse -File -Include *da*.*onnx | Select-Object -First 1
  if ($cand) {
    $PiperOnnx = $cand.FullName
    $cfg = Get-ChildItem $cand.DirectoryName -File -Filter *.json | Select-Object -First 1
    if ($cfg) { $PiperJson = $cfg.FullName }
  }
}

# --- OUTPUT ---
if (-not $OutPath) {
  $outDir = Join-Path $Root "out\speak"
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
  $OutPath = Join-Path $outDir ("{0:yyyyMMdd_HHmmss}_da.wav" -f (Get-Date))
} else {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ([IO.Path]::GetExtension($OutPath).ToLower() -ne ".wav") {
    $OutPath = [IO.Path]::ChangeExtension($OutPath, ".wav")
  }
}

# --- 1) PIPER DANSK (foretrukket) ---
if (-not $ForceSapi -and (Test-Path $PiperExe) -and (Test-Path $PiperOnnx) -and (Test-Path $PiperJson)) {
  Write-Host "[PIPER] Bruger dansk model:`n  exe : $PiperExe`n  onnx: $PiperOnnx`n  json: $PiperJson" -ForegroundColor Cyan
  $tmpTxt = [System.IO.Path]::GetTempFileName()
  Set-Content -Path $tmpTxt -Value $Text -Encoding UTF8
  & $PiperExe --model $PiperOnnx --config $PiperJson --output_file $OutPath --input_file $tmpTxt
  Remove-Item $tmpTxt -Force
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutPath)) { throw "Piper genererede ikke en fil." }
  Write-Host "[OK] Dansk TTS genereret (Piper): $OutPath" -ForegroundColor Green
  if ($Play) { Start-Process $OutPath }
  exit 0
}

# --- 2) WINDOWS SAPI (kun hvis dansk stemme findes) ---
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$da = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -ieq "da-DK" } | Select-Object -First 1
if ($da) {
  $s.SelectVoice($da.VoiceInfo.Name)
  $s.Rate = 0; $s.Volume = 100
  $s.SetOutputToWaveFile($OutPath)
  $s.Speak($Text)
  $s.SetOutputToDefaultAudioDevice()
  $s.Dispose()
  Write-Host "[OK] Dansk TTS genereret (Windows SAPI): $OutPath" -ForegroundColor Green
  if ($Play) { Start-Process $OutPath }
  exit 0
}
$s.Dispose()

# --- 3) Hvis vi kommer hertil, har du hverken Piper-da eller dansk SAPI ---
Write-Warning "Ingen dansk TTS fundet.
- Piper: mangler dansk model eller piper.exe
- Windows: mangler dansk stemme (da-DK)."

Write-Host "Sådan installerer du én af dem:" -ForegroundColor Yellow
Write-Host "A) Piper dansk model (anbefalet, lokal).
   1) Opret mappe:    $PiperModels
   2) Hent en dansk Piper-model (da_DK-*) til den mappe (onnx + json).
   3) Gem 'piper.exe' under:  $(Split-Path $PiperExe -Parent)
   4) Kør igen:  $($MyInvocation.MyCommand.Path) -Text 'Hej' -Play" -ForegroundColor Gray

Write-Host "B) Installer dansk Windows-stemme (kræver admin PowerShell):
   Add-WindowsCapability -Online -Name Language.Basic~~~da-DK~0.0.1.0
   Add-WindowsCapability -Online -Name Language.Speech~~~da-DK~0.0.1.0
   (genstart kan være påkrævet)" -ForegroundColor Gray

throw "Dansk TTS ikke tilgængelig endnu."
