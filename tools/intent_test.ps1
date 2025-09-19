param([string]$Heard)
function Normalize-DA {
  param([string]$s)
  if (-not $s) { return "" }
  $s = ($s -replace "(?i)^(hej|hey)\s+jarvis[,!\s]*","").Trim()
  $s = ($s -replace "\s+"," ").Trim()
  return $s
}
$cmd = Normalize-DA $Heard
if ($cmd -match "(?i)\b(tænd|taend)\b.*\blys\b.*\b(stue|stuen)\b") { "TTS: Tænder lyset i stuen." ; exit 0 }
elseif ($cmd -match "(?i)\b(sluk)\b.*\blys\b.*\b(stue|stuen)\b")   { "TTS: Slukker lyset i stuen." ; exit 0 }
elseif ($cmd -match "(?i)\bkan du h(ø|o)re mig\b")                { "TTS: Ja, jeg kan høre dig." ; exit 0 }
elseif ($cmd) { "ECHO: $cmd"; exit 0 }
"EMPTY"

