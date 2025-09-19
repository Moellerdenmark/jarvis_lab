param([Parameter(Mandatory=$true)][string]$Text,[string]$Voice="Helle",[double]$Rate=0)
$ErrorActionPreference="Stop"; Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Speech
$spk = New-Object System.Speech.Synthesis.SpeechSynthesizer
try{
  if($Voice){
    $v = $spk.GetInstalledVoices() | % { $_.VoiceInfo } | Where-Object { $_.Name -match $Voice }
    if($v){ $spk.SelectVoice($v[0].Name) }
  }
}catch{}
$spk.Rate = [int][Math]::Round([Math]::Max(-10,[Math]::Min(10,$Rate)))
$spk.Speak($Text)
