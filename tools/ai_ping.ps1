param([string]$Prompt="Sig: OK – jeg er klar.")
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$llm = Join-Path $tools 'llm.ps1'
if (-not (Test-Path $llm)) { throw "Mangler: $llm" }
(& $llm -Prompt ("Svar altid på dansk. " + $Prompt) | Out-String).Trim()
