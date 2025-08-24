param([string]$Text, [string]$Voice = "anders")

$Root  = "C:\Users\gubbi\jarvis_core"
$Piper = Join-Path $Root "piper\bin\piper.exe"
$Model = Join-Path $Root "piper\models\da-$Voice.onnx"
$Config= Join-Path $Root "piper\models\da-$Voice.onnx.json"
$Out   = Join-Path $Root "out\speak\last.wav"

# Kør Piper
& $Piper --model $Model --config $Config --output_file $Out --sentence "$Text"

# Afspil
Start-Process -FilePath $Out
