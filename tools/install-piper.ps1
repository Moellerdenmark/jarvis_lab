$ErrorActionPreference = "Stop"

# --- Stier ---
$Root     = "C:\Users\gubbi\jarvis_core"
$PiperDir = Join-Path $Root "piper"
$VoiceDir = Join-Path $PiperDir "voices"

# --- Download Piper portable (Windows) ---
Write-Host "Henter Piper..." -ForegroundColor Cyan
$zipUrl  = "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_windows_x64.zip"
$zipFile = Join-Path $Root "piper.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile

# Udpak
Expand-Archive -Path $zipFile -DestinationPath $PiperDir -Force
Remove-Item $zipFile

# --- Hent dansk stemme (medium kvalitet) ---
Write-Host "Henter dansk stemme..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $VoiceDir -Force | Out-Null
$voiceUrl = "https://github.com/rhasspy/piper/releases/download/v1.2.0/da_DK-nst_talesyntese-medium.onnx"
$cfgUrl   = "https://github.com/rhasspy/piper/releases/download/v1.2.0/da_DK-nst_talesyntese-medium.onnx.json"

Invoke-WebRequest -Uri $voiceUrl -OutFile (Join-Path $VoiceDir "da_DK-medium.onnx")
Invoke-WebRequest -Uri $cfgUrl   -OutFile (Join-Path $VoiceDir "da_DK-medium.onnx.json")

Write-Host "[OK] Piper og dansk stemme er installeret i $PiperDir" -ForegroundColor Green
