param([string]$RepoRoot)
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$readme = Join-Path $RepoRoot 'README.md'
if (-not (Test-Path $readme)) { Write-Host 'Post-sanitize: README.md not found'; return }

$txt    = Get-Content -Raw -Encoding UTF8 $readme
$check  = [char]0x2713
$double = "$check$check"

# Normaliser markører
$txt = [regex]::Replace($txt, 'PS-only\s+pipeline\s*\?+', "PS-only pipeline $double")
$txt = [regex]::Replace($txt, 'Jarvis\s+self-build\s*\?+', "Jarvis self-build $check")

# Balance triple backticks
$fences = ([regex]::Matches($txt,'```')).Count
if (($fences % 2) -ne 0) {
    $lines = $txt -split "`r?`n"
    for ($i = $lines.Length-1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\S') {
            if ($lines[$i].Trim() -eq '```') {
                $lines[$i] = ''
                $txt = ($lines -join "`r`n")
            } else {
                if (-not $txt.EndsWith("`r`n") -and -not $txt.EndsWith("`n")) { $txt += "`r`n" }
                $txt += '```'
            }
            break
        }
    }
}

# Trailing newline
if (-not $txt.EndsWith("`r`n") -and -not $txt.EndsWith("`n")) { $txt += "`r`n" }

Set-Content -Path $readme -Value $txt -Encoding UTF8
Write-Host 'Post-sanitize: OK'
