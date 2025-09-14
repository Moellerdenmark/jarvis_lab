param(
  [string]$Repo        = "C:\Users\gubbi\jarvis_ai",
  [string]$Core        = "C:\Users\gubbi\jarvis_core",
  [string]$BaseBranch  = "autopilot_main",
  [string]$Queue       = "ai_inbox",
  [int]$CiTimeoutMinutes = 60,
  [int]$AiStepTimeoutSec = 3600,
  [switch]$DryRun
)


# CFG_TIMEOUT_HOOK
try {
  Import-Module (Join-Path $PSScriptRoot 'lib\config.psm1') -Force
  if (-not $PSBoundParameters.ContainsKey('AiStepTimeoutSec')) {
    $cfg = Get-JarvisConfig
    if ($cfg.AiStepTimeoutSec) { $script:AiStepTimeoutSec = [int]$cfg.AiStepTimeoutSec }
  }
} catch {}
$ErrorActionPreference='Stop'
$PSCmd = (Get-Command pwsh -EA SilentlyContinue) ? 'pwsh' : 'powershell'
function Say([string]$m){ Write-Host ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }
function Run-Proc([string]$exe,[string[]]$args,[int]$timeout,[string]$name){
  $logDir = Join-Path $Repo 'tools\logs'; New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  $out = Join-Path $logDir ($name+'.out.log'); $err = Join-Path $logDir ($name+'.err.log')
  $p = Start-Process -FilePath $exe -ArgumentList $args -PassThru -NoNewWindow `
       -RedirectStandardOutput $out -RedirectStandardError $err
  if(-not $p.WaitForExit($timeout*1000)){ try{Stop-Process -Id $p.Id -EA SilentlyContinue}catch{}; throw "$name timeout efter ${timeout}s (se $out / $err)" }
  if($p.ExitCode -ne 0){ throw "$name fejlede med exit $($p.ExitCode) (se $out / $err)" }
}
if(-not (Get-Command git -EA SilentlyContinue)){ throw "git ikke fundet i PATH" }
if(-not (Get-Command gh  -EA SilentlyContinue)){ throw "GitHub CLI 'gh' kræves (gh auth login)" }

Set-Location $Repo
git fetch --all --prune | Out-Null
git checkout $BaseBranch | Out-Null
git pull --ff-only origin $BaseBranch | Out-Null

$lock = Join-Path $Repo '.autopilot.lock'
if(Test-Path $lock){ Remove-Item $lock -Force -EA SilentlyContinue }
New-Item -ItemType File -Force -Path $lock | Out-Null

try{
  $qPath = Join-Path $Repo $Queue
  if(-not (Test-Path $qPath)){ throw "Kømappe mangler: $qPath" }
  $task = Get-ChildItem $qPath -File -Filter *.md | Sort-Object Name | Select-Object -First 1
  if(-not $task){ Say "Ingen tasks i køen. Stopper.": return }
  Say ("Task: {0}" -f $task.Name)

  $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
  $fname=($task.BaseName -replace '[^a-zA-Z0-9_-]','-').Trim('-'); if(!$fname){$fname='task'}
  $feature="ai/autodev/$fname-$stamp"
  Say ("Ny gren: {0}" -f $feature)
  git checkout -b $feature $BaseBranch | Out-Null

  if($DryRun){
    Say "[DryRun] Skipper AI-step; laver placeholder ændring"
    "Updated: $(Get-Date -Format o)" | Out-File -Encoding utf8 -Append (Join-Path $Repo '.jarvis_dryrun')
  } else {
    $aiLoop = Join-Path $Repo 'tools\ai_loop.ps1'
    $orch   = Join-Path $Repo 'tools\orchestrator.ps1'
    if(Test-Path $aiLoop){
      Say "Kører ai_loop.ps1 (timeout ${AiStepTimeoutSec}s) — logs: tools\logs\ai_loop.*.log"
      Run-Proc $PSCmd @('-NoProfile','-ExecutionPolicy','Bypass','-File',$aiLoop,'-TaskFile',$task.FullName,'-Strict') $AiStepTimeoutSec 'ai_loop'
    } elseif(Test-Path $orch){
      Say "fallback: orchestrator.ps1 (timeout ${AiStepTimeoutSec}s) — logs: tools\logs\orch.*.log"
      Run-Proc $PSCmd @('-NoProfile','-ExecutionPolicy','Bypass','-File',$orch) $AiStepTimeoutSec 'orch'
    } else { throw "Mangler både tools\ai_loop.ps1 og tools\orchestrator.ps1" }
  }

  $tests=@(); $vs=Join-Path $Repo 'tools\tests\voice_smoke.ps1'; if(Test-Path $vs){$tests+=$vs}
  $sc=Join-Path $Repo 'tools\selfcheck.ps1';        if(Test-Path $sc){$tests+=$sc}
  foreach($t in $tests){ Say ("Kører test: {0}" -f $t); Run-Proc $PSCmd @('-NoProfile','-ExecutionPolicy','Bypass','-File',$t) 600 ('test_'+[IO.Path]::GetFileNameWithoutExtension($t)) }

  git add -A
  $changed=(git diff --name-only --cached | Out-String).Trim()
  if([string]::IsNullOrWhiteSpace($changed)){ throw "Ingen ændringer at committe" }
  git commit -m ("feat(jarvis): implement {0}" -f $task.BaseName) | Out-Null
  git push -u origin $feature | Out-Null

  $title="[Jarvis] $($task.BaseName)"; $body="Auto-created by orchestrator_strict on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Say "Opretter PR…"
  $out=(gh pr create -B $BaseBranch -t $title -b $body 2>&1 | Out-String)
  $pr =(gh pr view --json number -q ".number" 2>$null)
  if(-not $pr){ throw "Kunne ikke identificere PR. Output: $out" }
  Say ("Venter på CI checks for PR #{0}…" -f $pr)
  gh pr checks $pr --watch
  if($LASTEXITCODE -ne 0){ throw "CI checks fejlede for PR #$pr" }

  $deadline=(Get-Date).AddMinutes($CiTimeoutMinutes)
  do{ $merged=(gh pr view $pr --json merged -q ".merged" 2>$null); if($merged -eq 'true'){break}; Start-Sleep 10 } while((Get-Date) -lt $deadline)
  if($merged -ne 'true'){ throw "Timeout: PR #$pr ikke merged (>${CiTimeoutMinutes}m)" }
  Say ("PR #{0} er merged." -f $pr)

  git checkout $BaseBranch | Out-Null
  git pull --ff-only origin $BaseBranch | Out-Null
  $marker=Join-Path $Repo '.last_promoted'
  $last = (Test-Path $marker) ? (Get-Content $marker -Raw) : (git rev-list --max-parents=0 HEAD | Select-Object -First 1)
  $head = (git rev-parse HEAD).Trim()
  $files=(git diff --name-only $last $head | Out-String).Trim().Split("`n") | ? { $_ } | ? { $_ -notmatch '(^\.git|^\.github|^ai_inbox|^ai_tasks|\.md$)' }
  if(-not $files -or $files.Count -eq 0){ Say "Ingen promoverbare ændringer."; $head | Set-Content $marker }
  else{
    foreach($rel in $files){ $src=Join-Path $Repo $rel; $dst=Join-Path $Core $rel; New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null; Copy-Item -LiteralPath $src -Destination $dst -Force; Say ("Promoted: {0}" -f $rel) }
    $head | Set-Content $marker; Say ("Promotion complete → {0}" -f $Core)
  }
  Say "Færdig: 1 task behandlet, merged og promoveret."
}
finally{ if(Test-Path $lock){ Remove-Item $lock -Force -EA SilentlyContinue } }


