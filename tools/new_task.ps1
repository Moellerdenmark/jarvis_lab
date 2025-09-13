param(
  [Parameter(Mandatory=$true)][string]$Title,
  [string[]]$Files = @()
)
$dir = "ai_tasks"
if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
# find næste ledige nummer
$nums = Get-ChildItem $dir -Filter '*.md' -File | ForEach-Object {
  if($_.BaseName -match '^\d{3}'){
    [int]$_.BaseName.Substring(0,3)
  }
}
$next = if($nums){ ($nums | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$prefix = "{0:D3}" -f $next
$name = ($Title -replace '[^\w\- ]','').Trim() -replace '\s+','_'
$taskPath = Join-Path $dir ($prefix + '_' + $name + '.md')

# byg indhold
$lines = @()
$lines += ('Plan: ' + $Title)
$lines += 'FILES:'
foreach($f in $Files){ $lines += ('- ' + $f) }
if($Files.Count -eq 0){ $lines += '- README.md' }
$lines += 'Spec:'
$lines += '- Describe exactly what to change.'
$lines += ''
$lines += '```powershell'
$lines += '# Put any example commands here'
$lines += '```'
$lines += ''
$lines += 'Constraints:'
$lines += '- Do not touch core runtime.'
$lines += '- Run tests and commit only when green.'

Set-Content -Encoding ASCII -Path $taskPath -Value $lines
Write-Host ('Created ' + $taskPath) -ForegroundColor Green
