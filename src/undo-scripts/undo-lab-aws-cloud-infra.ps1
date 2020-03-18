param(
    [string] $workshopCfnStacks,
    [string] $ecrRepoName
)

Import-Module awspowershell.netcore # ToDo: Import into system's profile

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
# Include scripts with utility functions
. ../aws.ps1
. ../sys.ps1
Pop-Location

$workshopCfnStacks = CoalesceWithEnvVar $workshopCfnStacks "UNICORN_LAB_AWS_RIP_CFNS"
[string[]] $cfnStacksToDelete = $workshopCfnStacks.Split(",")

ConfigureCurrentAwsRegion -profileName $null
DeleteCfnStacks($cfnStacksToDelete)

$ecrRepoName = CoalesceWithEnvVar $ecrRepoName "UNICORN_LAB_AWS_RIP_ECR"
if($ecrRepoName)
{
    Remove-ECRRepository -RepositoryName $ecrRepoName -IgnoreExistingImages $true -Force -ErrorAction SilentlyContinue
    Write-Information "Removed ECR repository `"$ecrRepoName`""
}

TerminateInstanceByName(MakeLinuxInstanceName)
SetDockerHostUserEnvVar # Removes "DOCKER_HOST" env var
