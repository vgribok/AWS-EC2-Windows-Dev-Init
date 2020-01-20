param(
    [string[]] $workshopCfnStack = @(
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

ConfigureCurrentAwsRegion
DeleteCfnStacks($workshopCfnStack)

Remove-ECRRepository -RepositoryName $ecrRepoName -IgnoreExistingImages $true -Force -ErrorAction SilentlyContinue
Write-Host "Removed ECR repository `"$ecrRepoName`""