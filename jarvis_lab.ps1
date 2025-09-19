param([string]$Text = "", [switch]$SpeakBack)
$ErrorActionPreference = "Stop"
$lab  = "C:\Users\gubbi\jarvis_lab"
$tools= Join-Path $lab "tools"

. (Join-Path $tools "builder_agents.ps1")
Get-ChildItem -Path (Join-Path $tools "skills\*.ps1") -EA SilentlyContinue | ForEach-Object { . $_.FullName }

& (Join-Path $lab "jarvis.ps1") -Text $Text -SpeakBack:$SpeakBack
