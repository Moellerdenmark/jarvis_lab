param(
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)",
  [string]$VerifyName = "kenneth",
  [double]$VerifyThreshold = 0.72,
  [double]$VadSeconds = 1.0,
  [double]$VadSpeechRatio = 0.35,
  [double]$VadAutoMargin = 6.0,
  [double]$VerifySeconds = 1.2,
  [double]$SttSeconds = 4.0,
  [string]$Voice = "Helle",
  [switch]$SpeakBack,
  [int]$DelayMs = 120
)
$ErrorActionPreference="Stop"; Set-StrictMode -Version Latest; $InformationPreference="Continue"
try{ & "$env:WINDIR\System32\chcp.com" 65001 > $null }catch{}
try{ [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $OutputEncoding=[Text.UTF8Encoding]::new($false) }catch{}

$ScriptDir = if($PSScriptRoot){ $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root      = Split-Path -Parent $ScriptDir
$toolsDir  = $ScriptDir
$logDir    = Join-Path $Root "logs"
$outDir    = Join-Path $Root "out\listen"
New-Item -ItemType Directory -Force -Path $logDir,$outDir | Out-Null
$logFile   = Join-Path $logDir "vad_verify_stt.log"
function Log([string]$m){ $ts=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"); $l="[$ts] $m"; Add-Content -Path $logFile -Value $l -Encoding UTF8; Write-Host $l }

# === TTS flag + helper ===
$ttsFlag = Join-Path $Root 'out\listen\tts_busy.flag'
function WaitWhileTTS(){ $i=0; while(Test-Path $ttsFlag -and $i -lt 160){ Start-Sleep -Milliseconds 125; $i++ } }

function HasWake([string]$text){
  if(-not $text){ return $false }
  $s = $text.ToLowerInvariant()
  $s = $s -replace 'æ','ae' -replace 'ø','o' -replace 'å','a'
  $pats = @(
    '\bjarvis\b','\bjavis\b','\bjarvi\b','\bjarves\b','\bjarbis\b','\bjervis\b','\bjarwis\b',
    '\bjorvis\b','\bjarvz\b','\bjarwes\b','\bjobvis\b','\bj[ao]b+b[iy]s[h]?\b','\bj[ao]b+v[iy]s\b','\bhards\b',
    '\bj[aaoe]r?v[iy]s[h]?\b'
  )
  foreach($p in $pats){ if($s -match $p){ return $true } }
  return $false
}

function CleanText([string]$t){
  if(-not $t){ return "" }
  $t = $t.Trim()
  $t = ($t -replace '^\s*\[[^\]]+\]\s*','' -replace '^\s*-\s*','').Trim()
  $t = $t -replace '[,\.]+',' '
  $t = ($t -replace '\s+',' ').Trim()
  $words = $t -split '\s+'; $res = New-Object 'System.Collections.Generic.List[string]'; $prev=$null
  foreach($w in $words){ if($null -eq $prev -or $w -ne $prev){ $res.Add($w) }; $prev=$w }
  return ($res -join ' ')
}

function StripWakePrefix([string]$t){
  if(-not $t){ return "" }
  $greets = '(?:hejt|hej|hey|hei|hi|hallo|halloj|halløj|yo|okay|ok)'
  $wake   = '(?:j[aaoe]r?v[iy]s[h]?|j[ao]b+b[iy]s[h]?|j[ao]b+v[iy]s|jobvis|jorvis|jervis|jarwes|jarvz|hards)'
  $pat    = '^(?i)\s*(?:' + $greets + '\s+)?' + $wake + '\b[,:;!\.\s-]*'
  $out = $t
  while($out -match $pat){ $out = ($out -replace $pat,'').Trim() }
  $tmp = ($out -replace '(?i)\b' + $greets + '\b','')
  $tmp = ($tmp -replace '(?i)\b' + $wake   + '\b','').Trim()
  if(-not $tmp){ return "" }
  return $out
}

function IsCommand([string]$t){
  if(-not $t){ return $false }
  $t = $t.ToLowerInvariant()
  return ($t -match '^(åbn|open|vis|start|stop|sæt|saet|hvad|hva|spørg|spoerg|skriv)\b')
}

Log ("=== loop start (Device={0}) ===" -f $DeviceName)

while($true){
  try{
    if (Test-Path $ttsFlag) { Log 'TTS busy – pauser lytten'; WaitWhileTTS; Start-Sleep -Milliseconds $DelayMs; continue }

    $vad = & (Join-Path $toolsDir 'vad_gate.ps1') -Auto -Seconds $VadSeconds -AutoMargin $VadAutoMargin -MinSpeechBandRatio $VadSpeechRatio -DeviceName $DeviceName
    if($vad -ne 1){ Start-Sleep -Milliseconds $DelayMs; continue }

    $pass = & (Join-Path $toolsDir 'sv_verify.ps1') -Name $VerifyName -Seconds $VerifySeconds -Threshold $VerifyThreshold -DeviceName $DeviceName
    if($pass -ne 1){ Log 'Verify: FAIL'; Start-Sleep -Milliseconds $DelayMs; continue }
    Log 'Verify: PASS'

    $combined=""; $win=$SttSeconds
    for($i=0;$i -lt 2;$i++){
      $raw  = (& (Join-Path $toolsDir 'stt_mic_wrapper.ps1') -Seconds $win -DeviceName $DeviceName 2>$null *>&1 | Out-String)
      $line = ($raw -split "(`r`n|`n|`r)" | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
      if($line){
        $clean = CleanText $line
        if($clean){
          Log ("STT[{0}]: {1}" -f $i,$clean)
          if($combined){ $combined = ("{0} {1}" -f $combined,$clean).Trim() } else { $combined=$clean }
          if(HasWake $combined){ break }
        } else { Log ("STT[{0}]: (empty after clean)" -f $i) }
      } else { Log ("STT[{0}]: (no text)" -f $i) }
      $win = 2.0
    }
    if(-not (HasWake $combined)){
      if (IsCommand($combined)) { Log "Impliceret wake (kommandostart)"; }
      else { Log "Wakeword ikke fundet."; Start-Sleep -Milliseconds $DelayMs; continue }
    }
    Write-Host 'Wakeword fundet.' -ForegroundColor Green

    $seed = StripWakePrefix (CleanText $combined)

    Start-Sleep -Milliseconds 250
    $cmd=""

    $capRaw  = (& (Join-Path $toolsDir 'stt_mic_wrapper.ps1') -Seconds 4 -DeviceName $DeviceName 2>$null *>&1 | Out-String)
    $capLine = ($capRaw -split "(`r`n|`n|`r)" | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
    $cap     = ""; if($capLine){ $cap = StripWakePrefix (CleanText $capLine) }

    if($seed){ $cmd = $seed }
    if($cap){
      if($cmd){ $cmd = ("{0} {1}" -f $cmd,$cap).Trim() } else { $cmd = $cap }
    }

    if(-not $cmd){
      Log "CMD: (only wakeword)"
      if($SpeakBack){
        & (Join-Path $toolsDir 'speak_busy.ps1') -Text "Hvad vil du have mig til at gøre?" -Voice $Voice -Rate 1
        WaitWhileTTS
      }
      $capRaw2  = (& (Join-Path $toolsDir 'stt_mic_wrapper.ps1') -Seconds 4 -DeviceName $DeviceName 2>$null *>&1 | Out-String)
      $capLine2 = ($capRaw2 -split "(`r`n|`n|`r)" | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
      if($capLine2){
        $cap2 = StripWakePrefix (CleanText $capLine2)
        if($cap2){ $cmd = $cap2 }
      }
    }

    if($cmd){
      Log ("CMD: {0}" -f $cmd)
      if($SpeakBack){
        & (Join-Path $toolsDir 'speak_busy.ps1') -Text ("Okay. " + $cmd) -Voice $Voice -Rate 1
        WaitWhileTTS
      }
      & (Join-Path $Root 'jarvis.ps1') -Text $cmd -Voice $Voice -SpeakBack:$SpeakBack
      if (Test-Path (Join-Path $Root 'out\listen\stop.flag')) {
        Remove-Item (Join-Path $Root 'out\listen\stop.flag') -Force
        Log 'STOP flag set – exiting.'; break
      }
    } else {
      Log "CMD: (no text)"
    }

    Start-Sleep -Milliseconds 900
  }catch{
    Log ("ERROR: {0}" -f $_.Exception.Message)
  }
  Start-Sleep -Milliseconds $DelayMs
}
