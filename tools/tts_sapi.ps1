param(
    [string]$Text    = "Hej, jeg er Jarvis.",
    [string]$Voice   = "",           # substring på navn/ID, fx "Helle" eller "da-DK"
    [int]   $Rate    = 0,            # -10..10
    [int]   $Volume  = 100,          # 0..100
    [switch]$List                       # vis alle stemmer
)

Add-Type -AssemblyName System.Speech
$Synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

# Liste stemmer
if ($List) {
    $voices = $Synth.GetInstalledVoices() | ForEach-Object {
        $info = $_.VoiceInfo
        [pscustomobject]@{
            Name    = $info.Name
            Culture = $info.Culture
            Gender  = $info.Gender
            Age     = $info.Age
            Id      = $info.Id
        }
    }
    $voices | Format-Table -AutoSize
    return
}

# Vælg stemme:
$selected = $false
if ($Voice) {
    # match på substring i navn eller id (case-insensitive)
    foreach ($v in $Synth.GetInstalledVoices()) {
        $info = $v.VoiceInfo
        if ($info.Name -match [regex]::Escape($Voice) -or $info.Id -match [regex]::Escape($Voice)) {
            $Synth.SelectVoice($info.Name)
            $selected = $true
            break
        }
    }
} else {
    # prøv automatisk at vælge en dansk stemme
    foreach ($v in $Synth.GetInstalledVoices()) {
        if ($v.VoiceInfo.Culture.Name -eq "da-DK") {
            $Synth.SelectVoice($v.VoiceInfo.Name)
            $selected = $true
            break
        }
    }
}

# hvis intet valg lykkes, bruger den systemets standardstemme
$Synth.Rate   = $Rate
$Synth.Volume = $Volume
$Synth.Speak($Text)
