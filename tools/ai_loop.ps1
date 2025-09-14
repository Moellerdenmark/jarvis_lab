param([string]$TasksDir = "ai_tasks", [int]$MaxFixes = 1)
$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) { throw "Run in the jarvis_ai git worktree." }
git config core.quotepath false | Out-Null

# ---- Ollama ping + env ----
$ports = 11435,11434; $base = $null
foreach($p in $ports){
  try { Invoke-RestMethod -Uri "http://127.0.0.1:$p/api/tags" -Method GET -TimeoutSec 2 | Out-Null; $base="http://127.0.0.1:$p"; break } catch {}
}
if(-not $base){ throw "Cannot reach Ollama on 11435/11434. Start 'ollama serve'." }
$env:OLLAMA_HOST=$base; $env:OLLAMA_API_BASE=$base; $env:OLLAMA_BASE_URL=$base; $env:OLLAMA_KEEP_ALIVE="15m"; $env:AIDER_ANALYTICS="0"
try{
  $body=@{model="qwen2.5-coder:7b";prompt="ok";stream=$false}|ConvertTo-Json
  Invoke-RestMethod -Uri "$base/api/generate" -Method POST -Body $body -ContentType "application/json" | Out-Null
}catch{}

# ---- Baseline tests ----
& powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prove.ps1
if ($LASTEXITCODE -ne 0) { Write-Host "Baseline test FAILED – continuing (dev mode)" -ForegroundColor Yellow }

# ---- Mapper ----
if(-not (Test-Path $TasksDir)){ New-Item -ItemType Directory -Force -Path $TasksDir | Out-Null }
$doneDir   = Join-Path $TasksDir 'done'
$failedDir = Join-Path $TasksDir 'failed'
foreach($d in @($doneDir,$failedDir)){ if(-not (Test-Path $d)){ New-Item -ItemType Directory -Force -Path $d | Out-Null } }

# ---- Unik branch ----
$branch = "ai/autodev/" + (Get-Date -Format "yyyyMMdd_HHmmss_fff") + "_" + ([guid]::NewGuid().ToString("N").Substring(6))
if ((git branch --list $branch)) { git checkout $branch | Out-Null } else { git checkout -b $branch | Out-Null }
Write-Host ("Branch: " + $branch) -ForegroundColor Cyan

# ---- Find aider ----
$exe = @('.\.aider_venv\Scripts\aider.exe','..\.aider_venv\Scripts\aider.exe','..\.jarvis_core.venv\Scripts\aider.exe','aider') |
       Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $exe){ throw 'aider.exe not found. Install to .\.aider_venv or %USERPROFILE%\.aider_venv' }

# ---- Guardrail allowlist ----
$allow = @(
  '^README\.md$','^\.aider\.conf\.yml$','^\.gitattributes$','^\.gitignore$',
  '^CONTRIBUTING\.md$','^tools/selfcheck\.ps1$','^tools/new_task\.ps1$',
  '^tools/pull_inbox\.ps1$','^tools/orchestrator\.ps1$','^tools/prove\.ps1$',
  '^tools/.*\.md$','^ai_tasks/.*\.md$','^ai_tasks/done/.*','^ai_tasks/failed/.*',
  '^docs/.*','^logs/.*','^ai_inbox/.*'
)
function Is-Suspicious([string]$name){ foreach($rx in $allow){ if($name -match $rx){ return $false } } return $true }

# ---- Parse FILES: blok ----
function Get-TaskFiles([string]$taskPath){
  if(-not (Test-Path $taskPath)){ return @() }
  $lines = Get-Content $taskPath
  $files=@(); $in=$false
  foreach($ln in $lines){
    if($ln -match '^\s*FILES:\s*$'){ $in=$true; continue }
    if($in){
      if($ln -match '^\s*-\s*(\S+)\s*$'){ $files += $Matches[1]; continue }
      if($ln -match '^\s*$'){ break }
    }
  }
  return $files
}

# ---- Arkiv helper ----
function Archive-Task([string]$taskFile,[string]$state){
  $sub = if($state -eq 'ok'){'done'} else {'failed'}
  try{
    $name = Split-Path $taskFile -Leaf
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dst = Join-Path (Join-Path $TasksDir $sub) ("${stamp}_" + $name)
    Move-Item -LiteralPath $taskFile -Destination $dst -Force
    git add --all $TasksDir | Out-Null
    git commit -m ("chore(tasks): "+$sub+" "+$name) 2>$null | Out-Null
    Write-Host ("Archived task -> "+$sub+": " + $name) -ForegroundColor Green
  } catch {
    Write-Host ("Archive failed for: " + $taskFile + " -> " + $_.Exception.Message) -ForegroundColor Yellow
  }
}

# ---- Hj?lpere ----
function IsLikelyPath([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ return $false }
  $p = $p.Trim()
  if($p.StartsWith('"') -and $p.EndsWith('"')){ $p = $p.Substring(1, $p.Length-2) }
  if($p -match '^\- '){ $p = $p.Substring(2) }
  $bad = [IO.Path]::GetInvalidPathChars() -join ''
  if($p.IndexOfAny($bad.ToCharArray()) -ge 0){ return $false }
  return $true
}

# ---- K?r tasks ----
$todo = Get-ChildItem $TasksDir -Filter *.md -File | Where-Object { $_.Name -notlike '_repair_*' } | Sort-Object Name
foreach($t in $todo){
  Write-Host "`n=== TASK: $($t.Name) ===" -ForegroundColor Cyan
  $pre = (git rev-parse HEAD).Trim()

  # Kr?v FILES:
  [string[]]$taskFiles = @(Get-TaskFiles $t.FullName)
  if(-not $taskFiles -or $taskFiles.Count -eq 0){
    Write-Host 'Task mangler FILES:-liste -> markeres failed' -ForegroundColor Yellow
    Archive-Task -taskFile $t.FullName -state 'fail'
    git reset --hard $pre | Out-Null
    continue
  }

  # Begr?ns Aider med --file args og undg? at den r?rer .gitignore
  $fileArgs=@(); foreach($f in $taskFiles){ $fileArgs += @('--file', $f) }
  & $exe --config .aider.conf.yml --message-file $t.FullName @fileArgs --yes-always --no-show-model-warnings --no-gitignore --subtree-only

  # Reparationer ved r?de tests
  $ok=$false
  for($i=0; $i -le $MaxFixes; $i++){
    & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prove.ps1
    if($LASTEXITCODE -eq 0){ $ok=$true; break }
    $tmp = Join-Path $TasksDir ('_repair_'+$t.BaseName+'_try'+$i+'.txt')
    Set-Content -Encoding ASCII $tmp @(
      'Fix failing self-check. Only do what is necessary.',
      'Do NOT create new files except README.md and tools/*.ps1.',
      'Run tests and commit only when green.'
    )
    & $exe --config .aider.conf.yml --message-file $tmp @fileArgs --yes-always --no-show-model-warnings --no-gitignore --subtree-only
  }

  if(-not $ok){
    git reset --hard $pre | Out-Null
    Archive-Task -taskFile $t.FullName -state 'fail'
    continue
  }

  # Revert ?ndringer UDENFOR taskens FILES:
  [array]$changed = @(git diff --name-only "$pre" HEAD 2>$null)
  $extra=@()
  foreach($c in $changed){
    $isDeclared = $false
    foreach($tf in $taskFiles){ if($c -eq $tf){ $isDeclared=$true; break } }
    if(-not $isDeclared){ $extra += $c }
  }
  if($extra.Count -gt 0){
    foreach($x in $extra){ try{ & git checkout $pre -- "$x" | Out-Null }catch{} }
    git commit -m 'chore(ai): revert changes not declared in FILES' 2>$null | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prove.ps1
    if($LASTEXITCODE -ne 0){
      git reset --hard $pre | Out-Null
      Archive-Task -taskFile $t.FullName -state 'fail'
      continue
    }
  } else {
    Write-Host 'No changes - skipping external revert.' -ForegroundColor DarkGray
  }

  # Guardrail: fjern u?nskede tilf?jede filer (udenfor allowlist)
  if($changed.Count -gt 0){
    $bad = $changed | Where-Object { Is-Suspicious $_ }
    if($bad.Count -gt 0){
      git rm -f -- $bad | Out-Null
      git commit -m 'chore(ai): remove stray files from auto-run' 2>$null | Out-Null
    }
  } else {
    Write-Host 'No changes - skipping guardrail.' -ForegroundColor DarkGray
  }

  # Ryd untracked (robust)
  try{
    $un = git ls-files --others --exclude-standard
    if($un){
      $toDel = @()
      foreach($line in $un){
        if(IsLikelyPath $line){
          if(Is-Suspicious $line){ $toDel += $line }
        }
      }
      foreach($u in $toDel){ try{ if(Test-Path -LiteralPath $u){ Remove-Item -LiteralPath $u -Force -Recurse -EA SilentlyContinue } }catch{} }
      if($toDel.Count -gt 0){
        git add -A | Out-Null
        git commit -m 'chore(ai): clean untracked stray files' 2>$null | Out-Null
      }
    }
  }catch{
    Write-Host ('Cleanup skipped: ' + $_.Exception.Message) -ForegroundColor Yellow
  }

  Archive-Task -taskFile $t.FullName -state 'ok'
}

Write-Host "`nAll tasks processed on branch $branch" -ForegroundColor Green

