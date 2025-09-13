param([string]$Inbox="ai_inbox",[string]$TasksDir="ai_tasks")
$ErrorActionPreference = "Stop"
if(-not (Test-Path $Inbox)){ New-Item -ItemType Directory -Force -Path $Inbox | Out-Null }
if(-not (Test-Path $TasksDir)){ New-Item -ItemType Directory -Force -Path $TasksDir | Out-Null }

function Next-Idx([string]$dir){
  $nums = Get-ChildItem $dir -Filter "*.md" -File | ForEach-Object { if($_.BaseName -match "^\d{3}"){ [int]$_.BaseName.Substring(0,3) } }
  if($nums){ (($nums | Measure-Object -Maximum).Maximum + 1) } else { 1 }
}

$files = Get-ChildItem $Inbox -Filter *.md -File
foreach($f in $files){
  $n = Next-Idx $TasksDir
  $prefix = ("{0:D3}" -f ([int]$n))
  $safe = ($f.BaseName -replace "[^\w\- ]","").Trim() -replace "\s+","_"
  if([string]::IsNullOrWhiteSpace($safe)){ $safe = "task" }
  $dst = Join-Path $TasksDir ($prefix + "_" + $safe + ".md")
  Move-Item -LiteralPath $f.FullName -Destination $dst -Force
  Write-Host ("Pulled: " + $f.Name + " -> " + (Split-Path $dst -Leaf))
}

