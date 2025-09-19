# ====================== builder_agents.ps1 (Lab/Prod safe) ======================
$ErrorActionPreference = "Stop"
# Root = mappen over tools\ (dvs. jarvis_core ELLER jarvis_lab alt efter hvor filen ligger)
$Script:ThisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:Root    = Split-Path $Script:ThisDir -Parent
$tools = Join-Path $Script:Root 'tools'
$skills= Join-Path $tools 'skills'
New-Item -ItemType Directory -Force -Path $skills | Out-Null

# --- Minimal generate helper via Ollama ---
if (-not (Get-Command Invoke-OllamaGenerate -EA SilentlyContinue)) {
  function Invoke-OllamaGenerate {
    param(
      [Parameter(Mandatory)][string]$Model,
      [Parameter(Mandatory)][string]$Prompt,
      [int]$TimeoutMs = 120000,
      [hashtable]$Options
    )
    $base = $env:OLLAMA_HOST; if (-not $base) { $base = 'http://127.0.0.1:11434' }
    $body = @{ model=$Model; stream=$false; prompt=$Prompt; options=$Options } | ConvertTo-Json -Depth 20
    $resp = Invoke-RestMethod -Uri "$base/api/generate" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec ([Math]::Ceiling($TimeoutMs/1000))
    return $resp.response
  }
}

# --- JSON patch parser ---
if (-not (Get-Command ConvertFrom-JarvisPatchJson -EA SilentlyContinue)) {
  function ConvertFrom-JarvisPatchJson {
    param([Parameter(Mandatory)][string]$Json)
    $s = $Json.Trim() -replace '^\s*```(?:json)?','' -replace '```\s*$',''
    try { return @($s | ConvertFrom-Json -Depth 50) } catch {}
    $m = [regex]::Match($s, '\[\s*(\{.*\})\s*\]', 'Singleline')
    if ($m.Success) { try { return @($m.Value | ConvertFrom-Json -Depth 50) } catch {} }
    throw "Kunne ikke parse patch-JSON. Rå svar:`n$Json"
  }
}

# --- Patch applier: SKRIVER ALTID i det root hvor denne fil ligger (lab/prod) ---
if (-not (Get-Command Apply-JarvisPatch -EA SilentlyContinue)) {
  function Apply-JarvisPatch {
    param([Parameter(Mandatory)][object[]]$Patch,[switch]$Approve)
    foreach ($p in $Patch) {
      $rel = [string]$p.file
      if (-not $rel) { throw "Patch mangler 'file'." }
      if ($rel -notmatch '^(tools\\|jarvis\.ps1)') { throw "Ugyldig path: $rel (kun tools\\* eller jarvis.ps1 tilladt)" }
      $full = Join-Path $Script:Root $rel
      $dir  = Split-Path $full
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      $action=[string]$p.action; $content=[string]$p.content
      if (-not $Approve) { Write-Host "[DRY-RUN] $action -> $rel" -ForegroundColor Yellow; continue }
      switch ($action) {
        'create' { $content | Set-Content -Path $full -Encoding UTF8 }
        'append' { $content | Add-Content -Path $full -Encoding UTF8 }
        'replace-block' {
          $start=[string]$p.start; $end=[string]$p.end
          if ([string]::IsNullOrWhiteSpace($start) -or [string]::IsNullOrWhiteSpace($end)) { throw "replace-block kræver 'start' og 'end'." }
          if (-not (Test-Path $full)) {
            ($start + "`r`n" + $content + "`r`n" + $end + "`r`n") | Set-Content -Path $full -Encoding UTF8
          } else {
            $old = Get-Content $full -Raw
            $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
            $new = if ($old -match $pattern) {
              [regex]::Replace($old, $pattern, $start + "`r`n" + $content + "`r`n" + $end, 'Singleline')
            } else {
              $old + "`r`n" + $start + "`r`n" + $content + "`r`n" + $end + "`r`n"
            }
            $new | Set-Content -Path $full -Encoding UTF8
          }
        }
        default { throw "Ukendt action: $action" }
      }
      Write-Host "[OK] $action -> $rel" -ForegroundColor Green
    }
  }
}

# --- Rolle-agent helper ---
function Invoke-LLMAgent {
  param(
    [Parameter(Mandatory)][string]$RoleSystem,
    [Parameter(Mandatory)][string]$Message,
    [string]$Model = 'llama3.1:8b',
    [int]$TimeoutMs = 120000
  )
  $prompt = "System: $RoleSystem`nBruger: $Message`nSvar:"
  Invoke-OllamaGenerate -Model $Model -Prompt $prompt -TimeoutMs $TimeoutMs -Options @{
    temperature = 0.2; top_p = 0.9; num_ctx = 4096; stop = @('System:','Bruger:','Svar:')
  }
}

# --- Designer (giver KUN JSON patches) ---
function Invoke-JarvisDesigner {
  param([Parameter(Mandatory)][string]$Goal,[string]$Model='llama3.1:8b',[int]$TimeoutMs=120000)
  $sys = @"
Du er en deterministisk PowerShell-kodegenerator.
SVAR KUN med gyldig JSON (ingen markdown, ingen forklaringer, ingen spørgsmål).
Format: array af patch-objekter:
[
  { "file":"tools/skills/<navn>.ps1",
    "action":"create|append|replace-block",
    "start":"<marker start (kun ved replace-block)>",
    "end":"<marker slut (kun ved replace-block)>",
    "content":"<PowerShell kode>" }
]
Regler:
- Skriv kun i "tools\" eller "jarvis.ps1".
- Hvis info mangler: antag fornuftige defaults og læg TODO-kommentarer i koden. Stil ALDRIG spørgsmål.
- Koden SKAL være syntaktisk gyldig PowerShell.
- Ingen ``` og ingen tekst udenfor JSON.
"@
  $prompt = "System: $sys`nUser mål: $Goal`nOutput:"
  Invoke-OllamaGenerate -Model $Model -Prompt $prompt -TimeoutMs $TimeoutMs -Options @{
    temperature=0.1; top_p=0.85; num_ctx=4096; stop=@('System:','User mål:','Output:')
  }
}

# --- Orchestrator: Planner -> Coder -> Critic -> Tester (skriver i DETTE root) ---
function Jarvis-Orchestrate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Goal,
    [int]$MaxRounds = 2,
    [switch]$Approve,
    [string]$ModelPlanner = 'llama3.1:8b',
    [string]$ModelCoder   = 'llama3.1:8b',
    [string]$ModelCritic  = 'qwen2.5:7b-instruct',
    [string]$ModelTester  = 'qwen2.5:7b-instruct',
    [int]$TimeoutMs = 120000
  )

  $sysPlanner = @"
Du er "Planner". Lav en kort plan (max 6 punkter) for at opnå målet i Jarvis (PowerShell), men SVAR KUN med plan-tekst, ingen JSON.
"@
  $sysCoder = @"
Du er "Coder". Svar KUN med gyldig JSON array af patch-objekter (som beskrevet i builder). Ingen tekst udenfor JSON. Hvis planen mangler detaljer, vælg fornuftige defaults.
"@
  $sysCritic = @"
Du er "Critic". Tjek at JSON-patches er gyldige, skriver kun i tools\ eller jarvis.ps1, og at PowerShell-koden er syntaktisk korrekt. Hvis du finder fejl, ret og returnér KUN rettet JSON. Ellers returnér JSON uændret. Ingen tekst udenfor JSON.
"@
  $sysTester = @"
Du er "Tester". Returnér KUN JSON-objekt som {"test":"<powershell kommando der quick-tester den nye funktion/skill>"} — ingen forklaring.
"@

  $plan = Invoke-LLMAgent -RoleSystem $sysPlanner -Message $Goal -Model $ModelPlanner -TimeoutMs $TimeoutMs

  $patchJson = ''
  for ($round=1; $round -le $MaxRounds; $round++) {
    $patchJson = Invoke-LLMAgent -RoleSystem $sysCoder  -Message ("Mål: {0}`nPlan:`n{1}" -f $Goal, $plan) -Model $ModelCoder  -TimeoutMs $TimeoutMs
    $patchJson = Invoke-LLMAgent -RoleSystem $sysCritic -Message $patchJson                                          -Model $ModelCritic -TimeoutMs $TimeoutMs
    try {
      $patch = ConvertFrom-JarvisPatchJson -Json $patchJson
      Apply-JarvisPatch -Patch $patch -Approve:$Approve
      break
    } catch {
      if ($round -eq $MaxRounds) { throw }
      $plan = "FORBEDRINGSNOTE: $($_.Exception.Message)`nOriginal plan:`n$plan"
    }
  }

  try {
    $testerJson = Invoke-LLMAgent -RoleSystem $sysTester -Message ("Mål: {0}`nNy patch JSON:`n{1}" -f $Goal, $patchJson) -Model $ModelTester -TimeoutMs $TimeoutMs
    $testerObj  = $testerJson | ConvertFrom-Json
    if ($testerObj.test) { Write-Host "[TEST-FORSLAG] $($testerObj.test)" -ForegroundColor Cyan }
  } catch {
    Write-Host "[INFO] Ingen tester-kommando genereret." -ForegroundColor Yellow
  }
}
# ==================== /builder_agents.ps1 ====================

