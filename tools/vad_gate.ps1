param(
  [double]$Seconds = 0.8,
  [double]$MinSpeechBandRatio = 0.35,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)",
  [switch]$Auto,
  [double]$AutoMargin = 6.0,
  [string]$StateFile,
  [switch]$ResetBaseline,
  [switch]$Debug,
  [double]$MinRmsDb = -40.0
)
$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $ScriptDir 'sv_common.ps1')

$Root = Split-Path -Parent $ScriptDir
if (-not $StateFile) { $StateFile = Join-Path $Root "out\listen\vad_state.json" }
if ($ResetBaseline -and (Test-Path $StateFile)) { Remove-Item $StateFile -Force }

$out = Get-TempWavPath "vad"

# --- ffmpeg: stille og korrekt quoting ---
# NB: bruger -loglevel error så warnings (bl.a. "Guessed Channel Layout") ikke rammer stderr.
& ffmpeg -hide_banner -loglevel error `
  -f dshow -i ("audio=" + $DeviceName) `
  -t $Seconds -ac 1 -ar 16000 -vn -acodec pcm_s16le -y $out 2>$null | Out-Null

# Vent et øjeblik hvis filsystemet er lidt bagefter
$tries = 0
while (-not (Test-Path $out) -and $tries -lt 10) { Start-Sleep -Milliseconds 25; $tries++ }
if (-not (Test-Path $out)) {
  if ($Debug) { Write-Host "[VAD] ffmpeg skrev ingen fil (device busy eller forkert DeviceName?)" -ForegroundColor Yellow }
  0
  return
}

$r = Read-WavSamples16kMono $out
$x = $r.Samples
if (-not $x -or $x.Length -lt 3200) {
  if($Debug){Write-Host "[VAD] for kort prøve" -ForegroundColor Yellow}
  0
  return
}

# RMS
$sum=0.0; foreach($v in $x){ $sum += $v*$v }
$rms = [Math]::Sqrt($sum/[double]$x.Length)
$rmsDb = 20.0*[Math]::Log10([Math]::Max($rms,1e-12))

# Spektral tale-ratio
$fs = 16000; $nfft = 1024
[System.Numerics.Complex[]]$cx = New-Object 'System.Numerics.Complex[]' $nfft
$len = [Math]::Min($x.Length, $nfft)
for($i=0;$i -lt $len;$i++){ $cx[$i] = [System.Numerics.Complex]::new($x[$i],0) }
for($i=$len;$i -lt $nfft;$i++){ $cx[$i] = [System.Numerics.Complex]::Zero }
$X = Invoke-FFT $cx

$kMin = [int][Math]::Floor(150.0*$nfft/$fs)
$kMax = [int][Math]::Ceiling(3800.0*$nfft/$fs)
$Etot=0.0; $Espeech=0.0
for($k=0;$k -le $nfft/2;$k++){
  $p = $X[$k].Real*$X[$k].Real + $X[$k].Imaginary*$X[$k].Imaginary
  $Etot += $p
  if($k -ge $kMin -and $k -le $kMax){ $Espeech += $p }
}
$ratio = 0.0
if ($Etot -gt 0) { $ratio = $Espeech / $Etot } else { $ratio = 0.0 }

# Auto-baseline
$thrDb = $MinRmsDb
$baselineDb = $null
if ($Auto) {
  if (Test-Path $StateFile) {
    try { $st = Get-Content $StateFile -Raw | ConvertFrom-Json; $baselineDb = [double]$st.baselineDb } catch {}
  }
  if (-not $baselineDb) { $baselineDb = -55.0 }
  $likelyNoise = ($ratio -lt ($MinSpeechBandRatio*0.8))
  if ($likelyNoise) {
    $alpha = 0.90
    $baselineDb = $alpha*$baselineDb + (1.0-$alpha)*$rmsDb
    if ($baselineDb -lt -70) { $baselineDb = -70 }
    if ($baselineDb -gt -20) { $baselineDb = -20 }
  }
  $thrDb = [Math]::Max(-60.0, [Math]::Min(-30.0, $baselineDb + $AutoMargin))
  @{ baselineDb = [math]::Round($baselineDb,1); lastRmsDb = [math]::Round($rmsDb,1) } |
    ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
}

if ($Debug) {
  if ($Auto) {
    Write-Host ("[VAD] rmsDb={0:N1} ratio={1:N2} baseline={2:N1} -> thr={3:N1} (ratioThr {4})" -f $rmsDb,$ratio,$baselineDb,$thrDb,$MinSpeechBandRatio) -ForegroundColor Cyan
  } else {
    Write-Host ("[VAD] rmsDb={0:N1} ratio={1:N2} (thr {2} / {3})" -f $rmsDb,$ratio,$thrDb,$MinSpeechBandRatio) -ForegroundColor Cyan
  }
}

if ($rmsDb -ge $thrDb -and $ratio -ge $MinSpeechBandRatio) { 1 } else { 0 }
