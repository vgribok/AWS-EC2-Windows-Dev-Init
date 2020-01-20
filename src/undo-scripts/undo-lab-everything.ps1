param(
    # Top group of parameters will change from one lab to another
    [string] $labName = "dotnet-cdk",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $ecrRepoName = "unicorn-store-app",
    [string[]] $workshopCfnStack = @(
        "Unicorn-Store-CI-CD-PipelineStack",
        "UnicornSuperstoreStack"
    ),

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $tempIamUserPrefix = "temp-aws-lab-user"
)

[string[]] $gitUrls = @( $sampleAppGitHubUrl, $vsLicenseScriptGitHubUrl)

Push-Location
$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

Set-Location $scriptLocation
. ./undo-lab-sample-app-project.ps1 -workDirectory $workDirectory -gitUrls $gitUrls

Set-Location $scriptLocation
. ./undo-lab-aws-cloud-infra.ps1 -ecrRepoName $ecrRepoName -workshopCfnStack $workshopCfnStack

Set-Location $scriptLocation
. ./undo-lab-credentials.ps1 -labName $labName -tempIamUserPrefix $tempIamUserPrefix

Pop-Location

"Workshop cleanup is completed to the best of authors' ability, but please don't take our word for it still take a look around in AWS Console!"
