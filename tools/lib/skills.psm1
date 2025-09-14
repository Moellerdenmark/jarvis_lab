function Get-Registry {
  param([string]$Path = (Join-Path $PSScriptRoot '..\..\tools\skills\registry.yml'))
  $out=@{}; if(-not (Test-Path $Path)){ return $out }
  $name = $null
  foreach($line in (Get-Content $Path)){
    if($line -match '^\s*([A-Za-z0-9_\-]+):\s*$'){ $name=$matches[1]; $out[$name]=@{}; continue }
    if($line -match '^\s*path:\s*(.+)$'){ $out[$name]['path']=$matches[1].Trim() }
    if($line -match '^\s*allowed:\s*(\w+)$'){ $out[$name]['allowed']=($matches[1] -eq 'true') }
  }
  return $out
}
function Invoke-JarvisSkill {
  [CmdletBinding()] param([Parameter(Mandatory)][string]$Name,[hashtable]$Args)
  $reg = Get-Registry
  if(-not $reg.ContainsKey($Name)){ throw "Skill '$Name' findes ikke" }
  $e=$reg[$Name]
  if(-not $e.allowed){ throw "Skill '$Name' er ikke tilladt (allowed=false)" }
  $p = Join-Path (Join-Path $PSScriptRoot '..\..') $e.path
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $p @Args
}
Export-ModuleMember -Function Invoke-JarvisSkill,Get-Registry
