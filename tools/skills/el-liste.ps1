function Invoke-ElListe {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory,Position=0)][string]$Bullets
  )
  $lines = $Bullets -split "[;\r`n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  if (-not $lines) { return "Ingen punkter fundet." }

  function Parse-QtyUnit([string]$s){
    $o = [ordered]@{ Name=$null; Qty=1.0; Unit='stk' }
    $t = $s.Trim()

    # A) "2x navn" / "2× navn"
    $m = [regex]::Match($t,'^(?<qty>\d+(?:[.,]\d+)?)\s*(?:x|×)\s*(?<name>.+)$','IgnoreCase')
    if ($m.Success){
      $o.Qty  = [double]($m.Groups['qty'].Value.Replace(',','.'))
      $o.Name = $m.Groups['name'].Value.Trim(); return $o
    }
    # B) "navn 1.5 m" / "navn 2 stk"
    $m = [regex]::Match($t,'^(?<name>.+?)\s+(?<qty>\d+(?:[.,]\d+)?)\s*(?<unit>m|meter|mtr|stk|st|pcs)\b','IgnoreCase')
    if ($m.Success){
      $o.Name = $m.Groups['name'].Value.Trim()
      $o.Qty  = [double]($m.Groups['qty'].Value.Replace(',','.'))
      $u = $m.Groups['unit'].Value.ToLower()
      if ($u -match '^m') { $o.Unit='m' } elseif ($u -match 'stk|st|pcs') { $o.Unit='stk' }
      return $o
    }
    # C) "2 navn"
    $m = [regex]::Match($t,'^(?<qty>\d+(?:[.,]\d+)?)\s+(?<name>.+)$')
    if ($m.Success){
      $o.Qty  = [double]($m.Groups['qty'].Value.Replace(',','.'))
      $o.Name = $m.Groups['name'].Value.Trim(); return $o
    }
    # Default
    $o.Name = $t; return $o
  }

  $map = @{}
  foreach($ln in $lines){
    $p = Parse-QtyUnit $ln
    if (-not $p.Name) { continue }
    $key = ($p.Name -replace '\s+',' ').ToLower()
    if ($map.ContainsKey($key)){
      $acc = $map[$key]
      if ($acc.Unit -eq 'm' -or $p.Unit -eq 'm'){ $acc.Unit='m' }
      $acc.Qty += $p.Qty
    } else {
      $map[$key] = [ordered]@{ Name=$p.Name; Qty=$p.Qty; Unit=$p.Unit }
    }
  }

  $out = New-Object System.Collections.Generic.List[string]
  foreach($k in $map.Keys){
    $it = $map[$k]
    if ($it.Unit -eq 'm'){
      $out.Add( ('- {0} – {1:0.##} m' -f $it.Name, $it.Qty) )
    } else {
      $out.Add( ('- {0} – {1} stk' -f $it.Name, [int][math]::Round($it.Qty)) )
    }
  }
  ($out -join [Environment]::NewLine)
}
