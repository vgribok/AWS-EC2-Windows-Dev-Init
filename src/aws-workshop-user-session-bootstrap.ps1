<#
This script is invoked by Windows Startup folder each time suer logs in
#>
param(
    [string] $scriptDirectoryName = "~/AWS-EC2-Windows-Dev-Init/src"
)

Push-Location
Set-Location $scriptDirectoryName
& ./user-session-init.ps1
Pop-Location