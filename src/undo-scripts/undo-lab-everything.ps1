param(
    [string] $redirectToLog = $null,
    [string] $cleanupConfirmed = $null, # 1 - shutdown after cleanup, 2 - regular cleanup
    [string] $logFileName = "undo-script.log",

    # Top group of parameters will change from one lab to another
    [string] $sampleAppGitHubUrl,
    [string] $ecrRepoName,
    [string] $workshopCfnStacks,

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $tempIamUserPrefix = "temp-aws-lab-user"
)

if(-Not $cleanupConfirmed)
{
    Write-Host -NoNewline "Please choose an option:`n`nPress 1 if you need to clean up and plan to either shutdown or reboot the instance afterwards.`nPress 2 for regular cleanup. Enables re-initializing the system by running init scripts manually.`nClose this window to cancel cleaup.`n`n/1/2/x>"
    $cleanupConfirmed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character.ToString()
    Write-Host $cleanupConfirmed
}

switch($cleanupConfirmed.ToLowerInvariant())
{
    1 { $cleanupConfirmed = "shutdown" }
    2 { $cleanupConfirmed = "regular" }
    Default { return }
}

Write-Host "Conducting `"$cleanupConfirmed`" cleanup."

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

function Cleanup {
    param(
     [string] $scriptLocation,
     [string] $sampleAppGitHubUrl,
     [string] $ecrRepoName,
     [string] $workshopCfnStacks,
     [object] $cleanupConfirmed,
 
     [string] $workDirectory,
     [string] $vsLicenseScriptGitHubUrl,
     [string] $tempIamUserPrefix
    )

    $now = get-date
    Write-Information "Cleaup ($cleanupConfirmed) started on $now"
    
    Push-Location
    
    Set-Location $scriptLocation
    . ./undo-lab-sample-app-project.ps1 -workDirectory $workDirectory -sampleAppGitHubUrl $sampleAppGitHubUrl -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl
    
    Set-Location $scriptLocation
    . ./undo-lab-credentials.ps1 -tempIamUserPrefix $tempIamUserPrefix
    
    Set-Location $scriptLocation
    . ./undo-lab-aws-cloud-infra.ps1 -ecrRepoName $ecrRepoName -workshopCfnStack $workshopCfnStacks

    if($cleanupConfirmed -eq "shutdown")
    {   # Erase environment variables
        Set-Location $scriptLocation
        . ./undo-lab-sys.ps1        
    }

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
        -cleanupConfirmed $cleanupConfirmed `
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
        -cleanupConfirmed $cleanupConfirmed `
        -workDirectory $workDirectory `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -tempIamUserPrefix $tempIamUserPrefix
}
