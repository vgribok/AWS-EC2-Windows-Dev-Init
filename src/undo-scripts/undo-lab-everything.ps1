param(
    # Top group of parameters will change from one lab to another
    [string] $labName = "dotnet-cdk",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $ecrRepoName = "unicorn-store-app",
    [string[]] $workshopCfnStacks = @(
        "Unicorn-Store-CI-CD-PipelineStack",
        "UnicornSuperstoreStack"
    ),

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $tempIamUserPrefix = "temp-aws-lab-user",
    [string] $redirectToLog = $null,
    [string] $confirmed = $null
)

if(-Not $confirmed)
{
    $input = Read-Host -Prompt "[Y/N] Are you sure you want to de-provision lab AWS resources? The lab cannot be restarted before this instance is re-initialized"
    if($input.ToLowerInvariant() -ne "y")
    {
        "Cleanup cancelled."
        return
    }
}

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

function Cleanup {
    param(
     [string] $scriptLocation,
     [string] $labName,
     [string] $sampleAppGitHubUrl,
     [string] $ecrRepoName,
     [string[]] $workshopCfnStacks,
 
     [string] $workDirectory,
     [string] $vsLicenseScriptGitHubUrl,
     [string] $tempIamUserPrefix
    )

    $now = get-date
    "Cleaup started on $now"
    
    [string[]] $gitUrls = @( $sampleAppGitHubUrl, $vsLicenseScriptGitHubUrl)
    
    Push-Location
    
    Set-Location $scriptLocation
    . ./undo-lab-sample-app-project.ps1 -workDirectory $workDirectory -gitUrls $gitUrls
    
    Set-Location $scriptLocation
    . ./undo-lab-credentials.ps1 -labName $labName -tempIamUserPrefix $tempIamUserPrefix
    
    Set-Location $scriptLocation
    . ./undo-lab-aws-cloud-infra.ps1 -ecrRepoName $ecrRepoName -workshopCfnStack $workshopCfnStacks
    
    Set-Location $scriptLocation
    
    $now = get-date
    "Workshop cleanup is completed on $now to the best of authors' ability, but please don't take our word for it still take a look around in AWS Console!"
    
    Pop-Location
}

if($redirectToLog)
{
    [string] $logFileRelPath = Join-Path $scriptLocation "../../undo-script.log"
    $logFileLocation = [IO.Path]::GetFullPath($logFileRelPath)

    Write-Information "Output redirected to `"$logFileLocation`""
    Cleanup `
        -scriptLocation $scriptLocation `
        -labName $labName `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -ecrRepoName $ecrRepoName `
        -workshopCfnStacks $workshopCfnStacks `
        -workDirectory $workDirectory `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -tempIamUserPrefix $tempIamUserPrefix  `
        *> $logFileLocation
}else 
{
    Write-Information "Output is NOT redirected to a log file"
    Cleanup `
        -scriptLocation $scriptLocation `
        -labName $labName `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -ecrRepoName $ecrRepoName `
        -workshopCfnStacks $workshopCfnStacks `
        -workDirectory $workDirectory `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -tempIamUserPrefix $tempIamUserPrefix
}