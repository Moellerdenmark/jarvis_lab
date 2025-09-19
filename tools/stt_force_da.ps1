param()
$ErrorActionPreference = "Stop"
if (-not $PSScriptRoot) { $PSScriptRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path); if (-not $PSScriptRoot){ $PSScriptRoot = (Get-Location).Path } }

$OutDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\out\listen'))
$InWav  = Join-Path $OutDir 'jarvis_in_boosted.wav'
$OutTxt = Join-Path $OutDir 'last_stt.txt'
$ErrTxt = Join-Path $OutDir 'last_stt_err.txt'

$py = @"
import sys, traceback
from faster_whisper import WhisperModel

audio = r""" + '"' + "$InWav" + '"' + """
outp  = r""" + '"' + "$OutTxt" + '"' + """
errp  = r""" + '"' + "$ErrTxt" + '"' + """

try:
    model = WhisperModel("small", device="cpu", compute_type="int8")
    initial_prompt = ("Dansk samtale med en assistent ved navn Jarvis. "
                      "Mulige sætninger: 'Hej Jarvis, kan du høre mig?', "
                      "'Tænd lyset i stuen', 'Sluk lyset i stuen', 'Tak Jarvis'.")
    segments, info = model.transcribe(
        audio,
        language="da",
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=250),
        initial_prompt=initial_prompt,
        beam_size=5,
    )
    text = "".join(s.text for s in segments).strip()
    open(outp, "w", encoding="utf-8").write(text)
    sys.exit(0)
except Exception as e:
    open(errp, "w", encoding="utf-8").write("PYERR: " + str(e) + "\n" + traceback.format_exc())
    sys.exit(1)
"@

$tmpPy = Join-Path $OutDir 'transcribe_da_tmp.py'
$py | Set-Content -Path $tmpPy -Encoding UTF8

$python = Join-Path (Join-Path $PSScriptRoot '..') '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { $python = 'python' }

& $python $tmpPy
$code = $LASTEXITCODE

# Fallback hvis Python fejler eller ikke skrev filen:
if ($code -ne 0 -or -not (Test-Path $OutTxt)) {
  Write-Host "[force_da] Python fejlede – falder tilbage til stt.ps1" -ForegroundColor Yellow
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'stt.ps1') -Mode listen
}
