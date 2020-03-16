param(
    [string[]] $workshopCfnStacks = @(
        "Unicorn-Store-CI-CD-PipelineStack",
        "UnicornSuperstoreStack"
    ),
    [string] $ecrRepoName = "unicorn-store-app"
)

Import-Module awspowershell.netcore # ToDo: Import into system's profile

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
# Include scripts with utility functions
. ../aws.ps1
Pop-Location

ConfigureCurrentAwsRegion -profileName $null
DeleteCfnStacks($workshopCfnStacks)

Remove-ECRRepository -RepositoryName $ecrRepoName -IgnoreExistingImages $true -Force -ErrorAction SilentlyContinue
Write-Information "Removed ECR repository `"$ecrRepoName`""

TerminateInstanceByName(MakeLinuxInstanceName)
SetDockerHostUserEnvVar # Removes "DOCKER_HOST" env var
