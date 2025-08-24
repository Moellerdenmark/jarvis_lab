param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('Ebbe','Jarvis','Snape')]
  [string]$Voice,

  [Parameter(Mandatory=$false)]
  [string]$Text,

  [switch]$Play,

  [string]$VoicePath,
  [string]$OutPath,

  # Ønsket sprogkode. 'da' remappes automatisk til et understøttet sprog.
  [string]$Lang = "da",

  # XTTS er multi-speaker → vi giver et speaker-navn (kræves af Coqui TTS api)
  [string]$Speaker = "xtts",

  # Debug: vis den præcise tts-kommando og paths
  [switch]$VerboseArgs
)

$ErrorActionPreference = "Stop"

# ==== Stier / konstanter ====
$ROOT     = "C:\Users\gubbi\jarvis_core"
$OUTDIR   = Join-Path $ROOT "out\speak"
$TTS_EXE  = Join-Path $ROOT ".venv\Scripts\tts.exe"
$PY_EXE   = Join-Path $ROOT ".venv\Scripts\python.exe"
$MODEL    = "tts_models/multilingual/multi-dataset/xtts_v2"

# Forventet sprog-liste iflg. din build (fra din fejlmeddelelse):
$Supported = @('en','es','fr','de','it','pt','pl','tr','ru','nl','cs','ar','zh-cn','hu','ko','ja','hi')

# Profiler
$Profiles = @{
  "Ebbe"  = "C:\Users\gubbi\jarvis_core\voices\ref\ebbe_voice_isolated_clean.wav"
  "Jarvis"= "C:\Users\gubbi\jarvis_core\voices\ref\jarvis_voice_clean_only"
  "Snape" = "C:\Users\gubbi\jarvis_core\voices\ref\snape_voice_clean_only"
}

# ==== Tving CPU ====
$env:CUDA_VISIBLE_DEVICES = "-1"
$env:COQUI_TTS_DEVICE     = "cpu"
$env:PYTHONWARNINGS       = "ignore"

# ==== Tekst ====
if ([string]::IsNullOrWhiteSpace($Text)) { $Text = Read-Host "Skriv teksten der skal siges" }
if ([string]::IsNullOrWhiteSpace($Text)) { throw "Ingen tekst angivet." }

# ==== Speaker WAV resolver ====
function Resolve-SpeakerWav([string]$pathOrDir){
  if (-not $pathOrDir) { return $null }
  if (Test-Path $pathOrDir -PathType Leaf) { return (Resolve-Path $pathOrDir).Path }
  elseif (Test-Path $pathOrDir -PathType Container) {
    $wav = Get-ChildItem -Path $pathOrDir -Recurse -Include *.wav -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wav) { return $wav.FullName }
  }
  return $null
}

# ==== Profilvalg ====
$profilePath = if ($VoicePath) { $VoicePath } else { $Profiles[$Voice] }
if (-not $profilePath) { throw "Ingen profil defineret for stemmen '$Voice'." }

$speakerWav = Resolve-SpeakerWav $profilePath
if (-not $speakerWav) { throw "Kunne ikke finde en .wav for '$Voice'. Angiv -VoicePath til en WAV eller en mappe med WAV." }

# ==== Sprog-remap (da → nl som fallback) ====
$LangInternal = $Lang
if ($Supported -notcontains $LangInternal) {
  if ($Lang -eq 'da') {
    $LangInternal = 'nl'  # bedst match i din build
    Write-Warning "XTTS understøtter ikke 'da' i din version. Bruger 'nl' som intern sprogkode. Teksten kan stadig være dansk."
  } else {
    # vælg en sikker fallback
    $LangInternal = 'en'
    Write-Warning "Sprog '$Lang' er ikke understøttet. Faldt tilbage til '$LangInternal'."
  }
}

# ==== Output sti ====
if (-not (Test-Path $OUTDIR)) { New-Item -Path $OUTDIR -ItemType Directory | Out-Null }
if (-not $OutPath) {
  $stamp  = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $OutPath = Join-Path $OUTDIR "$($stamp)_$($Voice).wav"
}

# ==== Argumenter til Coqui CLI ====
$commonArgs = @(
  "--text", $Text,
  "--model_name", $MODEL,
  "--speaker", $Speaker,          # <<< VIGTIGT: gør Coqui tilfreds for multi-speaker
  "--speaker_wav", $speakerWav,
  "--language_idx", $LangInternal,
  "--out_path", $OutPath
)

if ($VerboseArgs) {
  Write-Host ("[ARGS] " + ($commonArgs -join " ")) -ForegroundColor Yellow
  Write-Host "[INFO] Voice: $Voice" -ForegroundColor Cyan
  Write-Host "[INFO] WAV  : $speakerWav" -ForegroundColor Cyan
  Write-Host "[INFO] Lang : $Lang  (intern: $LangInternal)" -ForegroundColor Cyan
  Write-Host "[INFO] Out  : $OutPath" -ForegroundColor Cyan
}

# ==== Kør TTS ====
if (Test-Path $TTS_EXE) {
  & $TTS_EXE @commonArgs
} elseif (Test-Path $PY_EXE) {
  & $PY_EXE -m TTS.bin.tts @commonArgs
} else {
  throw "Kunne ikke finde tts.exe eller python.exe i .venv. Er Coqui TTS installeret i venv?"
}

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutPath)) {
  throw "XTTS genererede ikke en gyldig fil."
}

Write-Host "[OK] Genereret: $OutPath" -ForegroundColor Green

# ==== Afspilning ====
if ($Play) {
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Media | Out-Null
    $player = New-Object System.Media.SoundPlayer
    $player.SoundLocation = $OutPath
    $player.Load()
    $player.PlaySync()
  } catch {
    Write-Warning "Afspilning fejlede i SoundPlayer. Åbner filen i standardafspiller..."
    Start-Process $OutPath
  }
}
