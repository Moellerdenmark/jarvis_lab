# PATH: tools\voice_enroll.ps1
param(
  [Parameter(Mandatory=$true)][string]$Name,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)",
  [string]$Phrase = "hej jarvis",
  [int]$Shots = 5,
  [int]$Seconds = 2
)
$ErrorActionPreference = "Stop"
$tools  = Split-Path -Parent $MyInvocation.MyCommand.Path
$root   = Split-Path -Parent $tools
$prof   = Join-Path $root "profiles\speakers\$Name"
$embed  = Join-Path $tools 'spk_embed.py'
$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) {
  $cand = @("$env:ProgramFiles\ffmpeg\bin\ffmpeg.exe","$env:ProgramFiles(x86)\ffmpeg\bin\ffmpeg.exe",(Join-Path $root "bin\ffmpeg.exe")) | ? { Test-Path $_ } | Select-Object -First 1
  $ff = $cand
}
if (-not $ff) { throw "ffmpeg ikke fundet" }
$listenDir = Join-Path $root "out\listen"
New-Item -ItemType Directory -Path $listenDir,$prof -Force | Out-Null
function Say($t){ try{ & (Join-Path $tools 'speak.ps1') -Text $t -Voice Helle -Rate 1 }catch{} }
Say "Okay $Name. Vi tager $Shots korte klip. Sig: $Phrase"
$clips=@()
for($i=1;$i -le $Shots;$i++){
  Say ("Klip {0} – tal nu." -f $i)
  $wav = Join-Path $listenDir ("enroll_{0:yyyyMMdd_HHmmss}_$i.wav" -f (Get-Date))
  & $ff -loglevel error -y -f dshow -i "audio=$DeviceName" -ac 1 -ar 16000 -t $Seconds "$wav" 2>$null
  if (-not (Test-Path $wav)) { throw "Optagelse fejlede ($i)" }
  $clips += $wav
  Start-Sleep -Milliseconds 300
}
# Vælg python
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
if (-not $py) { throw "Python ikke fundet" }
# Embeddings
$vecs=@()
foreach($p in $clips){
  $json = & $py (Join-Path $tools 'spk_embed.py') $p
  $o = $json | ConvertFrom-Json
  if ($o.error) { throw "Embedding fejl: $($o.error)" }
  $vecs += ,([double[]]$o.embedding)
}
# mean + L2
$dim = $vecs[0].Count
$sum = [double[]]::new($dim)
foreach($v in $vecs){ for($k=0;$k -lt $dim;$k++){ $sum[$k]+=$v[$k] } }
$mean = for($k=0;$k -lt $dim;$k++){ [double]($sum[$k]/$vecs.Count) }
$norm = [Math]::Sqrt(($mean | % { $_*$_ } | Measure-Object -Sum).Sum)
if ($norm -gt 1e-9){ for($k=0;$k -lt $dim;$k++){ $mean[$k]/=$norm } }
$meta = [pscustomobject]@{ name=$Name; phrase=$Phrase; created=(Get-Date).ToString("s"); shots=$Shots; mean=$mean }
New-Item -ItemType Directory -Path $prof -Force | Out-Null
$meta | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $prof 'voice.json') -Encoding UTF8
Say "Færdig. Jeg har lært din stemme, $Name."
"OK: $prof"
