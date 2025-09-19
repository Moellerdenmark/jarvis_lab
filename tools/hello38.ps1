$script = `nAuto hilsen $args.Count`n$_
& $PSScriptRoot\tools\hello.ps1 -Message "Auto hilsen 38" | Out-File -FilePath .\tools\hello38.ps1 -Encoding Utf8


