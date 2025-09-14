function Get-SystemPrompt {
  [CmdletBinding()]
  param([string]$DefaultPath = (Join-Path $PSScriptRoot '..\..\prompts\system\jarvis.da.md'))
  $cfgPath = Join-Path $PSScriptRoot '..\..\tools\models.psd1'
  $sys = $null
  if (Test-Path $cfgPath) {
    try {
      $cfg = Import-PowerShellDataFile $cfgPath
      if ($cfg.ContainsKey('SystemPromptPath') -and $cfg.SystemPromptPath) {
        if (Test-Path $cfg.SystemPromptPath) { $sys = Get-Content $cfg.SystemPromptPath -Raw }
      }
    } catch {}
  }
  if (-not $sys) { $sys = Get-Content $DefaultPath -Raw }
  return $sys
}
Export-ModuleMember -Function Get-SystemPrompt
