param([string]$Repo="C:\Users\gubbi\jarvis_ai")
$inbox = Join-Path $Repo "ai_inbox"; New-Item -ItemType Directory -Force -Path $inbox | Out-Null
function New-TaskFile([string]$Title,[string]$Body){
  $now  = Get-Date -Format "yyyyMMdd_HHmmss"
  $nums = (Get-ChildItem $inbox -File -Filter "*.md" | % { if($_.Name -match "^(\d{3})"){ [int]$matches[1] } }) + @(0)
  $next = "{0:d3}" -f (($nums | Measure -Maximum).Maximum + 1)
  $name = "${next}_${Title}_${now}.md"
  $path = Join-Path $inbox $name
  @"
$name
------------------------------------------------------------

$Body
"@ | Set-Content -Encoding UTF8 -LiteralPath $path
  Write-Host "Created: $path"
}
Write-Host "Interactive task prompt. Tom titel = afslut."
while($true){
  $t = Read-Host "Titel (fx jarvis_model)"
  if([string]::IsNullOrWhiteSpace($t)){ break }
  Write-Host "Skriv task-body (afslut med en enkelt '.' på egen linje):"
  $lines=@()
  while($true){ $l = Read-Host; if($l -eq '.'){ break } $lines += $l }
  New-TaskFile -Title $t -Body ($lines -join "`n")
}
