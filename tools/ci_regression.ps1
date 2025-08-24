$ErrorActionPreference = "Stop"
function _ok($m){ Write-Host $m -ForegroundColor Green }
function _er($m){ Write-Host $m -ForegroundColor Red }
. "$PSScriptRoot\selfbuild_guard.ps1"
$need = @('ConvertFrom-JarvisPatchJson','Jarvis-ValidatePatch','Apply-JarvisPatch','Jarvis-NormalizeRelPath','Resolve-JarvisPath','Jarvis-NormalizePs1')
$missing = @($need | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if (@($missing).Count -gt 0) { _er "SANITY: Mangler: $($missing -join ', ')"; exit 1 }
$samples = @()
$samples += @{ name='valid-json'; patch='{"actions":[{"op":"write","path":"tools/rt_valid.ps1","content":"Write-Output ""VALID"""}]}' }
$samples += @{ name='create-backslashes'; patch='{"actions":[{"op":"create","path":"tools\\rt_create.ps1","content":"Write-Output ""CREATE"""}]}' }
$samples += @{ name='md-fence-create'; patch="```json
{""actions"":[{""op"":""create"",""path"":""tools\\rt_create2.ps1"",""content"":""Write-Output \""CREATE2\"" ""}]}
```" }
$samples += @{ name='string-action'; patch='write tools/rt_string.ps1: Write-Output "STRING"' }
$samples += @{ name='nested-patch'; patch='{"patch":{"actions":[{"op":"append","path":"tools/rt_append.txt","content":"APPEND"}]}}' }
$samples += @{ name='ensure-mix'; patch='{"actions":[{"op":"ensureDir","path":"tools"},{"op":"ensureLine","path":"tools/rt_lines.txt","content":"LINE1"},{"op":"append","path":"tools/rt_lines.txt","content":"LINE2"}]}' }
$samples += @{ name='remove-nonexistent'; patch='{"actions":[{"op":"remove","path":"tools/rt_remove.ps1"}]}' }
$samples += @{ name='hello-number'; patch='{"actions":[{"op":"write","path":"tools/hello777.ps1","content":"(LLM-støj)"}]}' }
$failed = @()
foreach ($s in $samples) {
  try {
    $norm = $null
    try { $norm = Jarvis-ValidatePatch -Patch $s.patch }
    catch { $obj = ConvertFrom-JarvisPatchJson $s.patch; $norm = Jarvis-ValidatePatch -Patch $obj }
    Apply-JarvisPatch -Patch $norm -Approve:$true
    $written = @($norm.actions | Where-Object { $_.op -eq 'write' -and $_.path -match '\.ps1$' } | Select-Object -ExpandProperty path -ErrorAction Ignore)
    foreach ($p in $written) {
      $full = Resolve-JarvisPath -Path (Jarvis-NormalizeRelPath $p)
      $null = & powershell -ExecutionPolicy Bypass -File $full 2>&1 | Out-String
    }
  } catch {
    $failed += [pscustomobject]@{Case=$s.name; Error=$_.Exception.Message}
  }
}
if ($failed.Count -gt 0) { $failed | ForEach-Object { _er ("FAIL: {0} → {1}" -f $_.Case, $_.Error) }; exit 1 }
else { _ok "Alle regressioner OK." }