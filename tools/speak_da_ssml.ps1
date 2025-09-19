param(
  [Parameter(Mandatory=$true)]
  [string]$Text,

  # Alias er den lydnære udtale du ønsker
  [string]$JarvisAlias = "Jaris",

  [switch]$Play
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer

# Prøv at vælge dansk stemme hvis muligt
$da = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -ieq "da-DK" } | Select-Object -First 1
if ($da) { $s.SelectVoice($da.VoiceInfo.Name) }

# Erstat forekomster af 'Jarvis' med SSML-substitution
$escaped = [System.Security.SecurityElement]::Escape($Text)
$escaped = [System.Text.RegularExpressions.Regex]::Replace(
  $escaped, '(?i)\b(Jarvis)\b',
  "<sub alias=""$JarvisAlias"">Jarvis</sub>"
)

$ssml = @"
<speak version="1.0" xml:lang="da-DK">
  <voice xml:lang="da-DK">
    $escaped
  </voice>
</speak>
"@

$s.Rate = 0; $s.Volume = 100
$s.SpeakSsml($ssml)
$s.Dispose()
