param([string]$Repo="$((Resolve-Path "$PSScriptRoot\..\..").Path)")
$logs = Join-Path $Repo 'tools\logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
Write-Host "Tailing latest *.log in $logs (Ctrl+C for stop)"
while($true){
  $f = Get-ChildItem $logs -File -Filter '*.log' -EA SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if($f){ Get-Content $f.FullName -Tail 80 -Wait } else { Start-Sleep 1 }
}
