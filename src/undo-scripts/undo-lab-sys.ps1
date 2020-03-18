Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ../constants.ps1
Pop-Location

foreach ($envVarName in $knownEnvVars)
{
    [System.Environment]::SetEnvironmentVariable($envVarName, $null, [System.EnvironmentVariableTarget]::Machine)
    Write-Information "Removed Env Var: `"$envVarName`""
}