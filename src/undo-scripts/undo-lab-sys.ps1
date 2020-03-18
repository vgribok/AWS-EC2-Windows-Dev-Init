
[string[]] $knownEnvVars = @(
    "UNICORN_LAB_INIT_SCRIPT_BRANCH",
    "UNICORN_LAB_GUIDE_URL", "UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL", "UNICORN_LAB_SAMPLE_APP_GIT_BRANCH", 
    "UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR", "UNICORN_LAB_SAMPLE_APP_SOLUTION_FILE", "UNICORN_LAB_SAMPLE_APP_BUILD_CONFIG",
    "UNICORN_LAB_SAMPLE_APP_CDK_PORJ_DIR", "UNICORN_LAB_SAMPLE_APP_CODECOMMIT_REPO_NAME",
    "UNICORN_LAB_LINUX_DOCKER_START", "UNICORN_LAB_LINUX_DOCKER_AMI", "UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE"
)
foreach ($envVarName in $knownEnvVars)
{
    [System.Environment]::SetEnvironmentVariable($envVarName, $null, [System.EnvironmentVariableTarget]::Machine)
    Write-Information "Env Var: $envVarName=$([System.Environment]::GetEnvironmentVariable($envVarName))"
}