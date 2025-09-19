param(
  [Parameter(Mandatory=$true)][string]$Text,
  [string]$Voice = "Helle",
  [switch]$SpeakBack
)
$ErrorActionPreference="Stop"; Set-StrictMode -Version Latest
try{ [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $OutputEncoding=[Text.UTF8Encoding]::new($false) }catch{}
$ScriptDir = if($PSScriptRoot){$PSScriptRoot}else{ Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root      = Split-Path -Parent $ScriptDir
$toolsDir  = $ScriptDir

function Say([string]$t){ if($SpeakBack){ & (Join-Path $toolsDir 'speak.ps1') -Text $t -Voice $Voice -Rate 1 } }

# ---- Normalisering (tåler "Oben", engelske/danske varianter, citationstegn) ----
$raw = $Text
$txt = $raw.ToLowerInvariant()
$txt = $txt -replace '"',' ' -replace "'"," " -replace '[,\.]+',' ' -replace '\s+',' '
$txt = $txt -replace 'æ','ae' -replace 'ø','oe' -replace 'å','aa'
$txt = $txt.Trim()

# Hjælpe-funktioner
function IsMatch($pattern){ return ($txt -match $pattern) }
function After($pattern){ if($txt -match $pattern){ return $Matches[1].Trim() } return $null }
function OpenUrl($u){ Start-Process $u | Out-Null }

# ---- ÅBN/OPEN (åbn/åben/åbne/aabn/aaben/open/oben/start) ----
$openVerb = '(?:aabn|aaben|aa b n|aabne|aabner|aabner|aabn|abn|open|oben|start|starta|starte|startet|start)\b'
$openRx   = '(?i)^(?:' + $openVerb + ')\s+(.+)$'
$target   = After $openRx

if($target){
  # ryd støj i target
  $t = $target -replace '^\s*(the|min|mit|en|et)\s+','' -replace '\s+',' ' -replace '["“”]','' -replace '^:+',''
  # kendte apps (notesblok/notebook/notepad)
  if($t -match '^(?:notes?blok|notebook|note\s*book|notepad|note\s*pad|blok)$'){
    Start-Process notepad
    Say "Åbner Notesblok."
    return
  }
  # browser
  if($t -match '^(?:chrome|google\s*chrome|edge|browser|internet|web)$'){
    try{ Start-Process chrome } catch { Start-Process msedge }
    Say "Åbner browser."
    return
  }
  # lommeregner
  if($t -match '^(?:lommeregner|calculator|calc|regnemaskine)$'){
    Start-Process calc.exe
    Say "Åbner lommeregner."
    return
  }
  # youtube hurtig: "åbn youtube <søgeord>"
  if($t -match '^(?:youtube|yt)(?:\s+(.*))?$'){
    $q = if($Matches[1]){ $Matches[1].Trim() } else { "" }
    if($q){ OpenUrl ('https://www.youtube.com/results?search_query=' + [uri]::EscapeDataString($q)); Say ("YouTube: " + $q) }
    else   { OpenUrl 'https://www.youtube.com'; Say "Åbner YouTube." }
    return
  }
  # hvis det ligner en URL eller domæne → åbn direkte
  if($t -match '^(?:https?://|www\.)' -or $t -match '^[a-z0-9\-]+\.[a-z]{2,}(/\S*)?$'){
    if($t -notmatch '^https?://'){ $t = 'https://' + $t }
    OpenUrl $t
    Say "Åbner side."
    return
  }
  # fallback: prøv at starte som programnavn
  try{ Start-Process $t; Say ("Åbner " + $t + "."); return }catch{}
}

# ---- Søgning (søg/google/find) ----
$qq = After '(?i)^(?:soeg|søg|google|search|find)\s+(.+)$'
if($qq){
  $u = 'https://www.google.com/search?q=' + [uri]::EscapeDataString($qq)
  OpenUrl $u; Say ("Søger efter " + $qq); return
}

# ---- Tid ----
if(IsMatch '^(?i)(hvad er klokken|what time|current time)\b'){
  $t = (Get-Date).ToString('HH:mm')
  Say ("Klokken er " + $t); return
}

# ---- Noter ----
$note = After '(?i)^(?:skriv|tilfoej|tilføj|add)\s+(?:en\s+)?note[:\s]+(.+)$'
if($note){
  $nf = Join-Path $Root 'notes\notes.txt'
  New-Item -ItemType Directory -Force -Path (Split-Path $nf -Parent) | Out-Null
  Add-Content -Path $nf -Value ("[{0}] {1}" -f (Get-Date -f 'yyyy-MM-dd HH:mm'), $note) -Encoding UTF8
  Start-Process notepad $nf
  Say "Noter gemt."
  return
}

# ---- Stop ----
if(IsMatch '^(?i)(stop|sluk|quit|exit|afslut)\b'){
  $flag = Join-Path $Root 'out\listen\stop.flag'
  New-Item -ItemType File -Force -Path $flag | Out-Null
  Say "Stopper lytning."
  return
}

# ---- Fallback: sig det tilbage ----
Say ("Jeg hørte: " + $raw.Trim())
