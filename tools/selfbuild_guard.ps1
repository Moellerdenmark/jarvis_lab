param()
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot  # repo-root
$wrp  = Join-Path $root "tools\wrappers.ps1"
function _y($m){ Write-Host $m -ForegroundColor Yellow }
function _g($m){ Write-Host $m -ForegroundColor Green }
function _r($m){ Write-Host $m -ForegroundColor Red }
try {
  . $wrp
  _g "[GUARD] wrappers.ps1 indlæst."
  return
} catch {
  _y "[GUARD] Dot-sourcing fejlede: $($_.Exception.Message)"
  $bak = Get-ChildItem (Join-Path $root "tools") -Filter "wrappers.ps1.bak*" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($bak) {
    _y "[GUARD] Forsøger restore: $($bak.Name)"
    Copy-Item $bak.FullName $wrp -Force
    try { . $wrp; _g "[GUARD] Gendannet fra backup og indlæst."; return }
    catch { _r "[GUARD] Restore lykkedes ikke: $($_.Exception.Message)"; throw }
  } else { throw "[GUARD] Ingen backup fundet." }
}