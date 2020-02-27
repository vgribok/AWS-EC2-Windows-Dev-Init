param(
    [string] $redirectToLog = $null,
    [string] $cleanupConfirmed = $null,
    [string] $logFileName = "undo-script.log",

    # Top group of parameters will change from one lab to another
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $ecrRepoName = "unicorn-store-app",
    [string[]] $workshopCfnStacks = @(
        "Unicorn-Store-CI-CD-PipelineStack",
        "UnicornSuperstoreStack"
    ),

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $tempIamUserPrefix = "temp-aws-lab-user"
)

if(-Not $cleanupConfirmed)
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
    . ./undo-lab-credentials.ps1 -tempIamUserPrefix $tempIamUserPrefix
    
    Set-Location $scriptLocation
    . ./undo-lab-aws-cloud-infra.ps1 -ecrRepoName $ecrRepoName -workshopCfnStack $workshopCfnStacks
    
    Set-Location $scriptLocation
    
    $now = get-date
    "Workshop cleanup is completed on $now to the best of authors' ability, but please don't take our word for it still take a look around in AWS Console!"
    
    Pop-Location
}

if($redirectToLog)
{
    if($IsWindows)
    {
        $logFileDirPath = $env:SystemDrive + "\"
    }else 
    {
        $logFileDirPath = "/var/log/aws-workshop-init-scripts"
        mkdir $logFileDirPath -ErrorAction SilentlyContinue
    }

    $logFileLocation = Join-Path $logFileDirPath $logFileName
    Write-Information "Output redirected to `"$logFileLocation`""

    Cleanup `
        -scriptLocation $scriptLocation `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -ecrRepoName $ecrRepoName `
        -workshopCfnStacks $workshopCfnStacks `
        -workDirectory $workDirectory `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -tempIamUserPrefix $tempIamUserPrefix  `
        *> $logFileLocation # redirecting all output to a log file
}else 
{
    Write-Information "Output is NOT redirected to a log file"
    Cleanup `
        -scriptLocation $scriptLocation `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -ecrRepoName $ecrRepoName `
        -workshopCfnStacks $workshopCfnStacks `
        -workDirectory $workDirectory `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -tempIamUserPrefix $tempIamUserPrefix
}
