$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path) # ensures this script can be called from any directory
Push-Location
Set-Location $scriptLocation
. ./test-sys.ps1
Pop-Location
