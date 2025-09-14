param([string]$Repo="$((Resolve-Path "$PSScriptRoot\..\..").Path)")
$inbox = Join-Path $Repo 'ai_inbox'
New-Item -ItemType Directory -Force -Path $inbox | Out-Null
while($true){
  Clear-Host
  Write-Host "== ai_inbox (opdaterer hver 2. sekund) =="
  Get-ChildItem $inbox -File -Filter *.md -EA SilentlyContinue |
    Sort-Object Name |
    Format-Table Name,LastWriteTime -AutoSize
  Start-Sleep 2
}
