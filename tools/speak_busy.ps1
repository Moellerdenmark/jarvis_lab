param(
  [Parameter(Mandatory=$true)][string]$Text,
  [string]$Voice="Helle",
  [int]$Rate=0
)
$ErrorActionPreference="Stop"
try {
  Add-Type -AssemblyName System.Speech | Out-Null
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $Rate=[Math]::Max(-10,[Math]::Min(10,$Rate))
  $synth.Rate = $Rate
  if($Voice){
    $voices = $synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo }
    $pick = $voices | Where-Object { $_.Name -match $Voice } | Select-Object -First 1
    if(-not $pick){ $pick = $voices | Where-Object { $_.Culture.TwoLetterISOLanguageName -eq "da" } | Select-Object -First 1 }
    if($pick){ $synth.SelectVoice($pick.Name) }
  }
  $synth.Speak($Text)
} catch { Write-Host $Text }
