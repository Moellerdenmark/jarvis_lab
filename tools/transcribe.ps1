param(
  [string]$WavIn = "C:\Users\gubbi\jarvis_core\out\listen\jarvis_in_boosted.wav",
  [string]$Model = "small"
)

$VenvPy  = Join-Path $Root ".venv\Scripts\python.exe"
$OutDir  = Join-Path $Root "out\listen"
$TxtOut  = Join-Path $OutDir "last_stt.txt"
$TxtSrc  = [IO.Path]::ChangeExtension($WavIn,".txt")

Write-Host "[STT] Transskriberer $WavIn med model '$Model'..."

& $VenvPy -m whisper $WavIn `
  --model $Model `
  --language da `
  --fp16 False `
  --threads 4 `
  --output_dir $OutDir `
  --verbose False

if (Test-Path $TxtSrc) {
    Copy-Item $TxtSrc $TxtOut -Force
    $text = Get-Content $TxtOut -Raw
    Write-Host "[STT] Genkendt tekst: $text" -ForegroundColor Green
} else {
    Write-Host "[STT] Fejl: Ingen tekst fundet!" -ForegroundColor Red
}
