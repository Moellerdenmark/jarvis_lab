param(
  [Parameter(Mandatory=$true)][string]$Goal,
  [int]$Rounds = 3,
  [switch]$Speak,
  [int]$TimeoutSec = 90
)
$ErrorActionPreference = "Stop"

$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $tools
$out   = Join-Path $root 'autogen'
$logs  = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $out,$logs -Force | Out-Null

$session    = Get-Date -Format yyyyMMdd_HHmmss
$sessionDir = Join-Path $out $session
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

$trans = Join-Path $sessionDir 'transcript.md'
$log   = Join-Path $sessionDir 'auto.log'
$llm   = Join-Path $tools 'llm.ps1'

function Log([string]$t){
  $line = ('[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $t)
  $line | Out-File $log -Append -Encoding UTF8
  Write-Host $line
}
function Say([string]$t){ if($Speak){ try{ & (Join-Path $tools 'speak.ps1') -Text $t -Voice Helle -Rate 1 }catch{} } }

function Invoke-LLM([string]$Prompt,[int]$Timeout=$TimeoutSec){
  if (-not (Test-Path $llm)) { throw "Mangler: $llm" }
  if ($Timeout -le 0) { return ((& $llm -Prompt $Prompt | Out-String).Trim()) }

  Log "LLM start (timeout $Timeout s)"
  $job = Start-Job -ScriptBlock {
     param($llmPath,$p)
     try { (& $llmPath -Prompt $p | Out-String) } catch { "[LLM fejl] $($_.Exception.Message)" }
  } -ArgumentList $llm,$Prompt

  if (-not (Wait-Job $job -Timeout $Timeout)) {
    try{ Stop-Job $job -Force }catch{}
    Remove-Job $job -Force
    Log "LLM TIMEOUT"
    return "[Timeout] Ingen svar (>$Timeout s)."
  }

  $text = (Receive-Job $job | Out-String).Trim()
  Remove-Job $job -Force
  Log ("LLM OK – {0} tegn" -f $text.Length)
  return $text
}

$archInstr = "Du er 'Arkitekten'. Du foreslår konkrete PowerShell-ændringer og filer, der forbedrer systemet ift. målet.`nSvar ALTID på dansk. Når du foreslår kode, brug en ```powershell```-kodeblok og begynd første linje med: # PATH: relative\sti\fil.ps1"
$critInstr = "Du er 'Anmelderen'. Find fejl, PS 5.1-kompatibilitet, sikkerhed og robusthed. Svar kort på dansk med konkrete rettelser."
$ctx = ""

Add-Content $trans "# Auto-Improve $session`n`n**Mål:** $Goal`n"

for($i=1; $i -le $Rounds; $i++){
  Log "Runde $i / $Rounds – Arkitekt"
  $archPrompt = "Runde $i – Arkitekt.`nInstruktioner:`n$archInstr`n`nMål:`n$Goal`n`nKontekst hidtil:`n$ctx`n`nSvar:"
  $arch = Invoke-LLM $archPrompt
  Add-Content $trans "`n## Runde $i – Arkitekt`n$arch`n"
  Say ("Runde $($i): Arkitekten er færdig.")

  Log "Runde $i / $Rounds – Anmelder"
  $critPrompt = "Runde $i – Anmelder.`nInstruktioner:`n$critInstr`n`nArkitektens forslag:`n$arch`n`nSvar:"
  $crit = Invoke-LLM $critPrompt
  Add-Content $trans "`n## Runde $i – Anmelder`n$crit`n"
  Say ("Runde $($i): Anmelderen er færdig.")

  $ctx = "Arkitektens seneste svar:`n$arch`n`nAnmelderens seneste svar:`n$crit"
}

# Udtræk kodeblokke
$md       = Get-Content $trans -Raw
$pattern  = '```(?:powershell|ps1)\s*([\s\S]*?)```'
$regex    = New-Object System.Text.RegularExpressions.Regex ($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$matches  = $regex.Matches($md)
$exported = @()

foreach($m in $matches){
  $code = $m.Groups[1].Value
  $code = $code.TrimEnd("`r","`n")
  $firstLine = ($code -split "`r?`n")[0]
  $rel = $null
  if ($firstLine -match '#\s*PATH:\s*(.+)$'){ $rel = $Matches[1].Trim() }
  if (-not $rel) { $rel = "proposal_$([guid]::NewGuid().ToString('N')).ps1" }
  $dest = Join-Path $sessionDir $rel
  New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
  Set-Content -Path $dest -Value $code -Encoding UTF8
  $exported += $dest
}

# Pæn SUMMARY (uden System.Object[])
$summary = @()
$summary += "Session: $session"
$summary += "Mål: $Goal"
$summary += "Runder: $Rounds"
$summary += "Transkript: $trans"
$summary += "Log: $log"
$summary += "Eksporterede forslag:"
$summary += ($exported | ForEach-Object { " - $_" })
Set-Content -Path (Join-Path $sessionDir 'SUMMARY.txt') -Value ($summary -join "`n") -Encoding UTF8

Log ("Færdig. Eksporterede {0} fil(er)." -f $exported.Count)
