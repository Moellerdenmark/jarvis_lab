# tools/skills/el-sum.ps1
# Summerer en el-liste (linjer som: "- Navn — 2 stk (1,5 m)")
function Invoke-ElSum {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Text)

  $lines = ($Text -split "[\r\n;]+") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  if (-not $lines) { return "[el-sum] Ingen linjer fundet." }

  $agg = @{} # name -> @{ Count = int; Meters = double }
  $totalStk = 0
  $totalM   = 0.0

  foreach ($line in $lines) {
    $l = $line -replace '^\s*[-•–—]\s*',''  # fjern bullet
    $name = ($l -split '—')[0].Trim()       # venstre side før em-dash
    if (-not $name) { $name = $l.Trim() }

    $qty = 1
    if ($l -match '\b(\d+)\s*stk\b') { $qty = [int]$matches[1] }

    $m = $null
    if ($l -match '(\d+(?:[.,]\d+)?)\s*m\b') { $m = [double]($matches[1].Replace(',','.')) }

    # normaliser navn let
    $norm = ($name -replace '\s{2,}',' ' -replace '\s*,\s*', ', ').Trim()

    if (-not $agg.ContainsKey($norm)) { $agg[$norm] = @{ Count = 0; Meters = 0.0 } }
    $agg[$norm].Count  += $qty
    if ($m) { $agg[$norm].Meters += $m }

    $totalStk += $qty
    if ($m) { $totalM += $m }
  }

  $out = New-Object System.Collections.Generic.List[string]
  foreach ($k in ($agg.Keys | Sort-Object)) {
    $c = $agg[$k].Count
    $mm = $agg[$k].Meters
    if ($mm -gt 0) {
      $out.Add(("- {0} — {1} stk ({2} m)" -f $k, $c, ($mm.ToString('0.###').Replace('.',','))))
    } else {
      $out.Add(("- {0} — {1} stk" -f $k, $c))
    }
  }

  $sumLine = if ($totalM -gt 0) {
    "I alt: {0} stk, {1} m" -f $totalStk, ($totalM.ToString('0.###').Replace('.',','))
  } else {
    "I alt: {0} stk" -f $totalStk
  }
  $out.Add($sumLine) | Out-Null

  return ($out -join [Environment]::NewLine)
}
