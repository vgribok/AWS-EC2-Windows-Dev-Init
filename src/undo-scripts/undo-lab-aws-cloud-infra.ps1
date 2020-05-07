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

ConfigureCurrentAwsRegion

# Delete CFN stacks created in the course of the lab
$workshopCfnStacks = CoalesceWithEnvVar $workshopCfnStacks "UNICORN_LAB_AWS_RIP_CFNS"
DeleteCfnStacks($workshopCfnStacks)

# Delete ECR repo because non-empty repos won't be deleted by CFN templates that created them
[string] $ecrRepoNames = CoalesceWithEnvVar $ecrRepoName "UNICORN_LAB_AWS_RIP_ECR"
DeleteEcrRepos($ecrRepoNames)

TerminateInstanceByName(MakeLinuxInstanceName)
SetDockerHostUserEnvVar # Removes "DOCKER_HOST" env var
