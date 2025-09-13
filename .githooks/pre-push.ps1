$ErrorActionPreference = "Stop"

function Get-Upstream {
  try {
    $u = & git for-each-ref '--format=%(upstream:short)' HEAD 2>$null
    if ($u) { return $u.Trim() } else { return $null }
  } catch { return $null }
}

function Is-LfsTracked([string]$file) {
  try {
    $attr = (& git check-attr -a -- "$file" 2>$null | Out-String)
    return ($attr -match '(^|\s)filter:\s*lfs\b')
  } catch { return $false }
}

$limit = 50MB
$up    = Get-Upstream

# find filer ?ndret p? denne branch (eller alle trackede som fallback)
$files = @()
try {
  if ($up) {
    $base = (& git merge-base HEAD $up 2>$null).Trim()
    if ($base) { $files = @(& git diff --name-only "$base..HEAD" 2>$null) }
  }
} catch {}
if (-not $files -or $files.Count -eq 0) { $files = @(& git ls-files) }

$overs = @()
foreach($f in $files){
  if ([string]::IsNullOrWhiteSpace($f)) { continue }
  if (-not (Test-Path -LiteralPath $f)) { continue }
  if (Is-LfsTracked $f) { continue }
  try {
    $len = (Get-Item -LiteralPath $f).Length
    if ($len -gt $limit) {
      $overs += [PSCustomObject]@{ File=$f; MB=[math]::Round($len/1MB,1) }
    }
  } catch {}
}

if ($overs.Count -gt 0) {
  Write-Host "? Push blokeret: f?lgende filer er > 50 MB og ikke LFS-trackede:" -ForegroundColor Red
  foreach($o in $overs){ Write-Host ("  - {0}  ({1} MB)" -f $o.File, $o.MB) -ForegroundColor Red }
  Write-Host ""
  Write-Host "L?sning (Git LFS):" -ForegroundColor Yellow
  Write-Host '  git lfs install' -ForegroundColor Yellow
  Write-Host '  git lfs track "*.mp4" "*.zip" "*.bin" "*.iso"' -ForegroundColor Yellow
  Write-Host '  git add .gitattributes && git add <filer> && git commit -m "chore: track large binaries with LFS"' -ForegroundColor Yellow
  exit 1
}
exit 0
