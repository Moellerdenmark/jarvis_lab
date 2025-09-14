function Write-Turn {
  [CmdletBinding()] param(
    [Parameter(Mandatory)][ValidateSet('user','assistant')] [string]$Role,
    [Parameter(Mandatory)][string]$Text,
    [hashtable]$Meta
  )
  $day  = Get-Date -Format 'yyyyMMdd'
  $dir  = Join-Path (Join-Path $PSScriptRoot '..\..\logs\conversations') ''
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $file = Join-Path $dir "$day.jsonl"
  $obj  = [ordered]@{ ts=(Get-Date).ToString('o'); role=$Role; text=$Text; meta=$Meta }
  ($obj | ConvertTo-Json -Compress) | Add-Content -Path $file -Encoding UTF8
  return $file
}
Export-ModuleMember -Function Write-Turn
