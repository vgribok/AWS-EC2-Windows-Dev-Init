
[string[]] $knownEnvVars = @("UNICORN_LAB_INIT_SCRIPT_BRANCH", "UNICORN_LAB_LINUX_DOCKER_AMI", "UNICORN_LAB_LINUX_DOCKER_START", "UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE")
foreach ($envVarName in $knownEnvVars)
{
    [System.Environment]::SetEnvironmentVariable($envVarName, $null, [System.EnvironmentVariableTarget]::Machine)
    Write-Information "Env Var: $envVarName=$([System.Environment]::GetEnvironmentVariable($envVarName))"
}