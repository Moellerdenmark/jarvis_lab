# === Jarvis Builder v1 ===
# Krav: wrappers.ps1 indlæst (askdk_mini/askdk_pro + Invoke-OllamaGenerate)

# Sikkerhed: begræns skrivning til tools\ og jarvis.ps1
function Test-JarvisSafePath {
  param([Parameter(Mandatory)][string]$Path)
  $root  = 'C:\Users\gubbi\jarvis_core'
  $full  = [IO.Path]::GetFullPath($Path)
  $ok1   = $full -like (Join-Path $root 'tools\*')
  $ok2   = ($full -eq (Join-Path $root 'jarvis.ps1'))
  if (-not ($ok1 -or $ok2)) { throw "Ikke tilladt at skrive udenfor tools\ eller jarvis.ps1: $full" }
  return $full
}

# Vis ændringer (diff light)
function Show-TextDiff {
  param([string]$Old,[string]$New)
  $o = ($Old -split "`r?`n")
  $n = ($New -split "`r?`n")
  $max = [Math]::Max($o.Count,$n.Count)
  for($i=0;$i -lt $max;$i++){
    $l = if($i -lt $o.Count){$o[$i]}else{''}
    $r = if($i -lt $n.Count){$n[$i]}else{''}
    if ($l -ne $r) {
      Write-Host ('- ' + $l) -ForegroundColor Red
      Write-Host ('+ ' + $r) -ForegroundColor Green
    }
  }
}

# PATCH-format (JSON)
# [
#  { "file":"tools/skills/skill_led.ps1",
#    "action":"create|append|replace-block",
#    "start":"# <<< jarvis:skill led >>>",   # kun ved replace-block
#    "end":"# <<< /jarvis:skill led >>>",
#    "content":"...PS-kode..." }
# ]

function Apply-JarvisPatch {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][array]$Patch,
    [switch]$Approve
  )
  foreach($p in $Patch){
    $file = Join-Path 'C:\Users\gubbi\jarvis_core' $p.file
    $full = Test-JarvisSafePath $file

    $old = if (Test-Path $full) { Get-Content $full -Raw } else { '' }
    $new = $old

    switch ($p.action) {
      'create' {
        if (Test-Path $full) { throw "create: Fil findes allerede: $full" }
        $new = $p.content
      }
      'append' {
        $new = ($old + "`r`n" + $p.content)
      }
      'replace-block' {
        if (-not ($p.start) -or -not ($p.end)) { throw "replace-block kræver 'start' og 'end' markører" }
        if ($old -notmatch [regex]::Escape($p.start) -or $old -notmatch [regex]::Escape($p.end)) {
          throw "Kan ikke finde start/end markører i $full"
        }
        $pattern = [regex]::Escape($p.start) + '(?s).*?' + [regex]::Escape($p.end)
        $block   = $p.start + "`r`n" + $p.content.TrimEnd() + "`r`n" + $p.end
        $new     = [regex]::Replace($old, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
      }
      default { throw "Ukendt action: $($p.action)" }
    }

    Write-Host "Patch -> $full" -ForegroundColor Cyan
    Show-TextDiff -Old $old -New $new

    if ($Approve) {
      $dir = Split-Path $full
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      if (Test-Path $full) { Copy-Item $full "$full.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force }
      Set-Content -Path $full -Value $new -Encoding UTF8 -Force
      Write-Host "[SKREV] $full" -ForegroundColor Green
    } else {
      Write-Host "[TØR KØRSEL] Brug -Approve for at skrive." -ForegroundColor Yellow
    }
  }
}

function New-JarvisSkill {
  param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Description = "Jarvis skill: $Name"
  )
  $file = Join-Path 'C:\Users\gubbi\jarvis_core\tools\skills' ("{0}.ps1" -f $Name.ToLowerInvariant())
  $full = Test-JarvisSafePath $file
  if (Test-Path $full) { throw "Skill findes allerede: $full" }
  $content = @"
# $Description
# <<< jarvis:skill $Name >>>
function Invoke-$($Name){
  param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
  # TODO: implementér
  "Ikke implementeret endnu: $Name"
}
# <<< /jarvis:skill $Name >>>
"@
  Apply-JarvisPatch -Patch @(@{file=("tools/skills/{0}.ps1" -f $Name.ToLower()); action="create"; content=$content})
}

# Prompt der beder LLM om PATCH-JSON
function Invoke-JarvisDesigner {
  param(
    [Parameter(Mandatory)][string]$Goal,
    [string]$Model = 'llama3.1:8b',
    [int]$TimeoutMs = 120000
  )
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
- Skriveadgang KUN til 'tools\' og 'jarvis.ps1'.
- Hvis info mangler: antag fornuftige defaults og læg TODO-kommentarer i koden. Stil ALDRIG spørgsmål.
- Koden SKAL være syntaktisk gyldig PowerShell.
- Ingen ``` og ingen tekst udenfor JSON.
"@
  $prompt = "System: $sys`nUser mål: $Goal`nOutput:"
  Invoke-OllamaGenerate -Model $Model -Prompt $prompt -TimeoutMs $TimeoutMs -Options @{ temperature=0.1; top_p=0.85; num_ctx=4096; stop=@('System:','User mål:','Output:') }
}
]
Krav:
- Skriv kun i 'tools\' eller 'jarvis.ps1'.
- Koden skal være selvkørende og syntaktisk gyldig.
- Undgå eksterne moduler.
- Brug UTF8 uden BOM.
- Ingen forklaringer udenfor JSON.
"@

  $style = @"
Eksempel:
Mål: "Lav skill 'el-liste' der genererer en kort indkøbsliste til garage-LED ud fra 3 bullets"
Output (forkortet):
[
  {"file":"tools/skills/el-liste.ps1","action":"create","content":"...ps1..."}
]
"@

  $prompt = @"
System: $sys
[STYLE_START]
$style
[STYLE_END]
User mål: $Goal
Svar:
"@

  Invoke-OllamaGenerate -Model $Model -Prompt $prompt -TimeoutMs $TimeoutMs -Options @{ temperature=0.2; top_p=0.9; num_ctx=4096; stop=@('System:','[STYLE_START]','[STYLE_END]','User mål:','Svar:') }
}

function ConvertFrom-JarvisPatchJson {
  param([Parameter(Mandatory)][string]$Json)
  $s = $Json.Trim()
  $s = $s -replace '^\s*```(?:json)?','' -replace '```\s*
    return @($obj)
  } catch {
    throw "Kunne ikke parse patch-JSON. Rå svar:`n$Json"
  }
}

function Jarvis-Improve {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Goal,
    [switch]$Approve,
    [string]$Model = 'llama3.1:8b',
    [int]$TimeoutMs = 120000
  )
  $raw   = Invoke-JarvisDesigner -Goal $Goal -Model $Model -TimeoutMs $TimeoutMs
  $patch = ConvertFrom-JarvisPatchJson -Json $raw
  Apply-JarvisPatch -Patch $patch -Approve:$Approve
}

,''
  try { return @($s | ConvertFrom-Json -Depth 50) } catch {}
  $m = [regex]::Match($s, '\[\s*(\{.*\})\s*\]', 'Singleline')
  if ($m.Success) {
    try { return @($m.Value | ConvertFrom-Json -Depth 50) } catch {}
  }
  throw "Kunne ikke parse patch-JSON. Rå svar:`n$Json"
}
    return @($obj)
  } catch {
    throw "Kunne ikke parse patch-JSON. Rå svar:`n$Json"
  }
}

function Jarvis-Improve {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Goal,
    [switch]$Approve,
    [string]$Model = 'llama3.1:8b',
    [int]$TimeoutMs = 120000
  )
  $raw   = Invoke-JarvisDesigner -Goal $Goal -Model $Model -TimeoutMs $TimeoutMs
  $patch = ConvertFrom-JarvisPatchJson -Json $raw
  Apply-JarvisPatch -Patch $patch -Approve:$Approve
}


