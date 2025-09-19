param(
  [string]$Url  = "about:blank",
  [int]$Port    = 9222,
  [string]$Prof = "$env:LOCALAPPDATA\JarvisChrome\Profile"
)
$ErrorActionPreference = "Stop"

function Get-BrowserPath {
  $chrome = Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"
  if (-not (Test-Path $chrome)) { $chrome = Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe" }
  if (Test-Path $chrome) { return $chrome }
  $edge = Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"
  if (-not (Test-Path $edge)) { $edge = Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe" }
  if (Test-Path $edge) { return $edge }
  throw "Hverken Chrome eller Edge fundet."
}

$bin = Get-BrowserPath
New-Item -ItemType Directory -Force -Path $Prof | Out-Null

# Luk alt og start ny CDP-instans
taskkill /f /im chrome.exe 2>$null | Out-Null
taskkill /f /im msedge.exe 2>$null | Out-Null

$args = @(
  "--remote-debugging-port=$Port",
  "--user-data-dir=`"$Prof`"",
  "--new-window",
  $Url
)
Start-Process -FilePath $bin -ArgumentList $args | Out-Null
Start-Sleep -Seconds 2
