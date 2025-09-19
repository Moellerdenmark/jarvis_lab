# ================= lab_helpers.ps1 (clean rebuild) =================

function Ensure-LLMAgentsLoaded {
  $tools = Join-Path $env:USERPROFILE 'jarvis_lab\tools'
  foreach($f in 'wrappers.ps1','builder.ps1','builder_agents.ps1'){
    $p = Join-Path $tools $f
    if (Test-Path $p) { . $p }
  }
  if (-not (Get-Command Invoke-OllamaGenerate -EA SilentlyContinue)) {
    throw 'wrappers.ps1 er ikke indlæst – mangler Invoke-OllamaGenerate.'
  }
  if (-not (Get-Command Jarvis-Orchestrate -EA SilentlyContinue)) {
    throw 'builder_agents.ps1/builder.ps1 er ikke indlæst – mangler Jarvis-Orchestrate.'
  }
  if (-not (Get-Command ConvertFrom-JarvisPatchJson -EA SilentlyContinue)) {
    throw 'builder.ps1 ikke indlæst – mangler ConvertFrom-JarvisPatchJson.'
  }
  if (-not (Get-Command Apply-JarvisPatch -EA SilentlyContinue)) {
    throw 'builder.ps1 ikke indlæst – mangler Apply-JarvisPatch.'
  }
  try { Invoke-RestMethod "$env:OLLAMA_HOST/api/tags" -TimeoutSec 3 | Out-Null }
  catch { throw ("Ollama utilgængelig: " + $_.Exception.Message) }
}

function Assert-JarvisSyntax([string]$Path){
  $t=$null;$e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e){ throw ("Syntaxfejl i {0}: {1}" -f $Path, $e[0].Message) }
}

function Assert-JarvisSmoke([string]$Jarvis){
  $ok1 = & $Jarvis -Text 'el-liste: A 1 stk; B 2 stk'
  $ok2 = & $Jarvis -Text @"
el-sum:
- A — 1 stk
- B — 2 stk
"@
  if(-not ($ok1 -match 'A' -and $ok2 -match 'I alt')){
    throw 'Smoke-tests fejlede.'
  }
}

function Promote-JarvisLab {
  param(
    [switch]$WhatIf,
    [string]$Lab  = "$env:USERPROFILE\jarvis_lab",
    [string]$Core = "$env:USERPROFILE\jarvis_core"
  )
  Assert-JarvisSyntax (Join-Path $Lab  'jarvis.ps1')
  Assert-JarvisSmoke  (Join-Path $Lab  'jarvis_lab.ps1')

  $stamp  = Get-Date -Format yyyyMMdd-HHmmss
  $backup = Join-Path $Core ("backup-" + $stamp)
  New-Item -ItemType Directory -Force -Path $backup | Out-Null

  foreach($src in @((Join-Path $Lab 'jarvis.ps1'), (Join-Path $Lab 'tools'))){
    $dst = $Core
    Write-Host "[PROMOTE] $src -> $dst" -ForegroundColor Cyan
    if(-not $WhatIf){
      Copy-Item -Recurse -Force -Path (Join-Path $Core (Split-Path $src -Leaf)) -Destination $backup -ErrorAction SilentlyContinue
      Copy-Item -Recurse -Force -Path $src -Destination $dst
    }
  }
  if($WhatIf){ Write-Host "(WhatIf) Ingen filer kopieret." -ForegroundColor Yellow }
  else       { Write-Host ("[OK] Promovering færdig. Backup i: {0}" -f $backup) -ForegroundColor Green }
}

function Jarvis-AutoBuild {
  param(
    [Parameter(Mandatory)][string]$Goal,
    [int]$MaxRounds = 2
  )
  $ErrorActionPreference = 'Stop'
  $env:JARVIS_TARGET = 'lab'  # skriv KUN i LAB

  Ensure-LLMAgentsLoaded

  try {
    Jarvis-Orchestrate -Goal $Goal -Approve -MaxRounds $MaxRounds
  } catch {
    $logDir = Join-Path $env:USERPROFILE 'jarvis_lab\out'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $log = Join-Path $logDir ("build-error-{0}.log" -f (Get-Date -Format yyyyMMdd-HHmmss))
    ($_ | Out-String) | Set-Content -Path $log -Encoding UTF8
    Write-Warning ("[BUILD FEJL] Orchestrator stoppede. Forbliver i LAB. Se: {0}" -f $log)
    return
  }

  Assert-JarvisSyntax (Join-Path $env:USERPROFILE 'jarvis_lab\jarvis.ps1')
  Assert-JarvisSmoke  (Join-Path $env:USERPROFILE 'jarvis_lab\jarvis_lab.ps1')

  Promote-JarvisLab
}
# ================= /lab_helpers.ps1 =================
