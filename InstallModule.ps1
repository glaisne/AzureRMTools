$ModuleName = "AzureTools"
$ModulePath = "C:\Program Files\WindowsPowerShell\Modules"
$TargetPath = "$($ModulePath)\$($ModuleName)"

Copy-Item -Verbose -Path "$PSScriptRoot\$ModuleName" -Destination $ModulePath -Container -Recurse -Force