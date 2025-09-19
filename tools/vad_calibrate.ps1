param(
  [double]$Seconds = 2.0,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)"
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sv_common.ps1"

$noiseWav = Get-TempWavPath "vad_noise"
Write-Host "[CAL] Optager støjgulv $Seconds s → $noiseWav" -ForegroundColor Cyan
ffmpeg -hide_banner -loglevel warning -f dshow -i "audio=$DeviceName" -t $Seconds -ac 1 -ar 16000 -vn -acodec pcm_s16le -y "$noiseWav" 2>$null

$r = Read-WavSamples16kMono $noiseWav
$x = $r.Samples
$sum=0.0; foreach($v in $x){ $sum += $v*$v }
$rms = [Math]::Sqrt($sum/[double]$x.Length)
$noiseDb = 20.0*[Math]::Log10([Math]::Max($rms,1e-12))

# Sæt tærskel lidt over støjgulv (6 dB margin), clamp mellem -60 og -35 dB
$thr = [Math]::Max(-60.0, [Math]::Min(-35.0, $noiseDb + 6.0))

Write-Host ("[CAL] Noise floor: {0:N1} dBFS → foreslået MinRmsDb = {1:N1} dBFS" -f $noiseDb, $thr) -ForegroundColor Green
Write-Host ("[TIP] Kør fx: & `"$tools\vad_gate.ps1`" -Seconds 1.0 -MinRmsDb {0:N0} -MinSpeechBandRatio 0.35 -Debug" -f $thr) -ForegroundColor Yellow
