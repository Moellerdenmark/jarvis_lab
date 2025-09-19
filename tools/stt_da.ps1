param()
$ErrorActionPreference = "Stop"
if (-not $PSScriptRoot) {
  $PSScriptRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
  if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
}

# Paths
$OutDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\out\listen'))
$InWav  = Join-Path $OutDir 'jarvis_in_boosted.wav'
$OutTxt = Join-Path $OutDir 'last_stt.txt'
if (-not (Test-Path $InWav)) { throw "Mangler lydfil: $InWav" }

# Build Python with JSON-safe quoting
$audioJson = $InWav | ConvertTo-Json
$outJson   = $OutTxt | ConvertTo-Json

$py = @"
from faster_whisper import WhisperModel

audio = {AUDIO_JSON}
outp  = {OUT_JSON}

model = WhisperModel("small", device="cpu", compute_type="int8")
initial_prompt = ("Dansk samtale med en assistent ved navn Jarvis. "
                  "Sætninger som: 'Hej Jarvis, kan du høre mig?', "
                  "'Tænd lyset i stuen', 'Sluk lyset i stuen', 'Tak Jarvis'.")

segments, info = model.transcribe(
    audio,
    language="da",
    vad_filter=True,
    vad_parameters=dict(min_silence_duration_ms=200),
    initial_prompt=initial_prompt,
    beam_size=5,
)

text = "".join(s.text for s in segments).strip()
open(outp, "w", encoding="utf-8").write(text)
print(text)
"@

$py = $py.Replace("{AUDIO_JSON}", $audioJson).Replace("{OUT_JSON}", $outJson)

$tmpPy = Join-Path $OutDir 'transcribe_da_tmp.py'
$null = New-Item -ItemType Directory -Force -Path $OutDir -ErrorAction SilentlyContinue
$py | Set-Content -Path $tmpPy -Encoding UTF8

$python = Join-Path (Join-Path $PSScriptRoot '..') '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { $python = 'python' }

& $python $tmpPy
if ($LASTEXITCODE -ne 0) { throw "stt_da fejlede" }
