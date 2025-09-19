param([Parameter(Mandatory=$true)][string]$Wav)
$ErrorActionPreference = "Stop"

# Basestier
$tools  = Split-Path -Parent $MyInvocation.MyCommand.Path
$root   = Split-Path -Parent $tools
$bin    = Join-Path $root "bin"
$models = Join-Path $root "models"
$logDir = Join-Path $root "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$elog   = Join-Path $logDir "errors.log"

# Hurtig WAV-check
if (-not (Test-Path -LiteralPath $Wav)) {
  ("[{0}] STT: WAV mangler: {1}" -f (Get-Date), $Wav) | Out-File $elog -Append -Encoding UTF8
  return ""
}

# Scoop-stier
$scoopShim = Join-Path $env:USERPROFILE "scoop\shims\whisper-cli.exe"
$scoopApp  = Join-Path $env:USERPROFILE "scoop\apps\whisper-cpp\current"

# Vælg exe (Scoop-shim foretrækkes, ellers lokal bin)
$exeCandidates = @()
if (Test-Path $scoopShim) { $exeCandidates += $scoopShim }
$exeCandidates += @('whisper-cli.exe','whisper.exe','whisper-cpp.exe','main.exe') | ForEach-Object { Join-Path $bin $_ }
$exe = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) {
  ("[{0}] STT: ingen whisper exe fundet." -f (Get-Date)) | Out-File $elog -Append -Encoding UTF8
  return ""
}

# Vælg model
$model = @('ggml-small-q5_1.bin','ggml-small.bin','ggml-base-q5_1.bin','ggml-base.bin') |
         ForEach-Object { Join-Path $models $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $model) {
  ("[{0}] STT: ingen whisper-model fundet." -f (Get-Date)) | Out-File $elog -Append -Encoding UTF8
  return ""
}

try {
  $prefix  = Join-Path $env:TEMP ("stt_" + [IO.Path]::GetFileNameWithoutExtension($Wav))
  $threads = [Math]::Max(2, [Environment]::ProcessorCount - 4)
  $argsArr = @('-m', $model, '-f', $Wav, '-l', 'da', '-otxt', '-of', $prefix, '-t', "$threads")

  # Kør hvor ggml*.dll findes (Scoop-app hvis vi kalder shim, ellers exe-mappen)
  if ((Test-Path $scoopShim) -and (Test-Path $scoopApp) -and ($exe -eq $scoopShim)) { $wd = $scoopApp } else { $wd = Split-Path $exe -Parent }

  # Byg kommandolinje med korrekt anførselstegn
  $argLine = ($argsArr | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '

  # Start stille via .NET så vi kan læse streams og exitcode
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName               = $exe
  $psi.Arguments              = $argLine
  $psi.WorkingDirectory       = $wd
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true

  $proc = [System.Diagnostics.Process]::Start($psi)
  $null  = $proc.StandardOutput.ReadToEnd()  # ignorer
  $stderr= $proc.StandardError.ReadToEnd()   # indeholder ofte "loading model ..." (ikke fejl)
  $proc.WaitForExit()

  $txtPath = "$prefix.txt"
  if ((Test-Path $txtPath) -and ((Get-Item $txtPath).Length -gt 0)) {
    return ((Get-Content $txtPath -Raw) -replace '\r?\n',' ').Trim()
  } else {
    # Kun log hvis exitcode != 0 — ellers er manglende .txt den "rigtige" indikator
    if ($proc.ExitCode -ne 0) {
      $firstErr = ($stderr -split "`r?`n")[0]
      ("[{0}] STT: whisper exitcode {1}. {2}" -f (Get-Date), $proc.ExitCode, $firstErr) | Out-File $elog -Append -Encoding UTF8
    }
    return ""
  }
}
catch {
  ("[{0}] STT: exception: {1}" -f (Get-Date), $_.Exception.Message) | Out-File $elog -Append -Encoding UTF8
  return ""
}
