param(
  [Parameter(Mandatory=$true)]
  [string]$Text,

  # Forsøger først dansk ("da-DK"); ellers vælger nærmeste installerede stemme.
  [string]$Culture = "da-DK",

  # Valgfrit: navnet på en bestemt installeret stemme (overstyrer $Culture)
  [string]$VoiceName,

  # -10 (langsom) til +10 (hurtig)
  [int]$Rate = 0,

  # 0..100
  [int]$Volume = 100,

  # Gem også til WAV (valgfrit)
  [string]$OutPath,

  # Afspil den gemte WAV (hvis -OutPath er angivet)
  [switch]$Play
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer

# Vælg stemme
$chosen = $null
if ($VoiceName) {
  if (($s.GetInstalledVoices() | ForEach-Object {$_.VoiceInfo.Name}) -contains $VoiceName) {
    $s.SelectVoice($VoiceName); $chosen = $VoiceName
  } else {
    throw "Stemme '$VoiceName' findes ikke. Kør: Get-InstalledVoices"
  }
} else {
  # Prøv kulturmatch (fx da-DK)
  $voice = $s.GetInstalledVoices() |
    Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -ieq $Culture } |
    Select-Object -First 1
  if ($voice) {
    $s.SelectVoice($voice.VoiceInfo.Name); $chosen = $voice.VoiceInfo.Name
  } else {
    # Fallback: første tilgængelige
    $voice = $s.GetInstalledVoices() | Where-Object { $_.Enabled } | Select-Object -First 1
    if (-not $voice) { throw "Ingen installerede Windows-stemmer fundet." }
    $s.SelectVoice($voice.VoiceInfo.Name); $chosen = $voice.VoiceInfo.Name
    Write-Warning "Fandt ikke '$Culture'. Brugerintern fallback: '$($voice.VoiceInfo.Name)' ($($voice.VoiceInfo.Culture))."
  }
}

# Tempo/lydstyrke
$s.Rate   = [Math]::Max(-10, [Math]::Min(10, $Rate))
$s.Volume = [Math]::Max(0, [Math]::Min(100, $Volume))

if ($OutPath) {
  # Sørg for mappe og .wav
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ([IO.Path]::GetExtension($OutPath).ToLower() -ne ".wav") {
    $OutPath = [IO.Path]::ChangeExtension($OutPath, ".wav")
  }
  $s.SetOutputToWaveFile($OutPath)
  $s.Speak($Text)
  $s.SetOutputToDefaultAudioDevice()
  Write-Host "[OK] Gemte: $OutPath (stemme: $chosen)" -ForegroundColor Green
  if ($Play) { Start-Process $OutPath }
} else {
  # Taler direkte uden fil
  Write-Host "[INFO] Stemme: $chosen  |  Kultur: $Culture  |  Rate: $($s.Rate)  |  Volume: $($s.Volume)"
  $s.Speak($Text)
}
$s.Dispose()

function Get-InstalledVoices {
  Add-Type -AssemblyName System.Speech
  $tmp = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $tmp.GetInstalledVoices() | ForEach-Object {
    [PSCustomObject]@{
      Name    = $_.VoiceInfo.Name
      Culture = $_.VoiceInfo.Culture
      Gender  = $_.VoiceInfo.Gender
      Age     = $_.VoiceInfo.Age
      Id      = $_.VoiceInfo.Id
    }
  }
  $tmp.Dispose()
}
