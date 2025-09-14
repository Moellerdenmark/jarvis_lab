function Build-Index {
  [CmdletBinding()]
  param([string]$Root = (Join-Path $PSScriptRoot "..\..\knowledge"))

  $files = Get-ChildItem -Path $Root -Recurse -File -Filter *.md -EA SilentlyContinue
  $idx = @()
  foreach ($f in $files) {
    $txt   = Get-Content -LiteralPath $f.FullName -Raw
    $title = [IO.Path]::GetFileNameWithoutExtension($f.Name)

    $matches = [regex]::Matches($txt,'[A-Za-z0-9_-]{4,}')
    $seen = @{}
    $keys = @()
    foreach ($m in $matches) {
      $w = $m.Value.ToLowerInvariant()
      if (-not $seen.ContainsKey($w)) { $seen[$w] = 1; $keys += $w }
      if ($keys.Count -ge 30) { break }
    }

    $preview = if ($txt.Length -gt 200) { $txt.Substring(0,200) } else { $txt }
    $idx += [pscustomobject]@{ title=$title; path=$f.FullName; keywords=$keys; preview=$preview }
  }

  $out  = Join-Path $Root ".index.json"
  $json = ConvertTo-Json $idx -Depth 5
  Set-Content -LiteralPath $out -Value $json -Encoding utf8NoBOM
  Write-Host ("Build-Index: {0} filer -> {1}" -f $files.Count, $out)
  return $out
}

function Select-Snippets {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Query,
    [int]$Max = 3,
    [string]$Root = (Join-Path $PSScriptRoot "..\..\knowledge")
  )
  $idxPath = Join-Path $Root ".index.json"
  if (-not (Test-Path $idxPath)) { [void](Build-Index) }

  $idx   = Get-Content -LiteralPath $idxPath -Raw | ConvertFrom-Json
  $terms = $Query.ToLowerInvariant().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)

  $scored = @()
  foreach ($e in $idx) {
    $kw = @()
    foreach ($k in $e.keywords) { $kw += $k.ToString().ToLowerInvariant() }
    $score = 0
    foreach ($t in $terms) { if ($kw -contains $t) { $score++ } }
    $scored += [pscustomobject]@{ path=$e.path; title=$e.title; score=$score; preview=$e.preview }
  }

  $result = @()
  foreach ($item in ($scored | Sort-Object -Property score -Descending)) {
    if ($item.score -gt 0) { $result += $item; if ($result.Count -ge $Max) { break } }
  }
  return $result
}

Export-ModuleMember -Function Build-Index,Select-Snippets
