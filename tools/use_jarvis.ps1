param([switch]$Test)
$mf = Join-Path $PSScriptRoot '..\models\jarvis.Modelfile'
& ollama create jarvis -f $mf 2>$null | Out-Null
if($LASTEXITCODE -ne 0){ Write-Host "ollama create jarvis (OK eller allerede findes)" }
if($Test){ & ollama run jarvis "hej" }
