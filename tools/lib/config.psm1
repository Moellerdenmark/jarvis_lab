function Merge-Deep([hashtable]$a,[hashtable]$b){
  $o=@{}; foreach($k in ($a.Keys + $b.Keys | Select-Object -Unique)){
    if($a.ContainsKey($k) -and $b.ContainsKey($k) -and ($a[$k] -is [hashtable]) -and ($b[$k] -is [hashtable])){
      $o[$k] = Merge-Deep $a[$k] $b[$k]
    } else {
      $o[$k] = if($b.ContainsKey($k)){$b[$k]} else {$a[$k]}
    }
  }; return $o
}
function Get-JarvisConfig {
  [CmdletBinding()] param()
  $defaultsPath = Join-Path $PSScriptRoot '..\..\tools\models.psd1'
  $localPath    = Join-Path $PSScriptRoot '..\..\tools\local.config.psd1'
  $def = if(Test-Path $defaultsPath){ Import-PowerShellDataFile $defaultsPath } else { @{} }
  $loc = if(Test-Path $localPath){ Import-PowerShellDataFile $localPath } else { @{} }
  return (Merge-Deep $def $loc)
}
Export-ModuleMember -Function Get-JarvisConfig,Merge-Deep
