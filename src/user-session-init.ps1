<#
This script is started on user login by a shortcut in the "Startup" directory to the batch file on C:\.
#>

param(
    [string] $afterLoginScriptGitUrl,
    [string] $workDirectory = "~/AWS-workshop-assets"
)

function ShowInitInProgressMessage {
    param ($progressMessage)
    
    Write-Progress `
        -Activity 'SYSTEM INITIALIZATION IN PROGRESS! -------------- SYSTEM INITIALIZATION IN PROGRESS! -------------- SYSTEM INITIALIZATION IN PROGRESS!' `
        -Status "PLEASE WAIT FOR THIS MSSAGE TO GO AWAY BEFORE DOING ANYTHING! ($progressMessage)";
}

function WaitForInitScriptLogFileCreation {
    $i = 1
    while (-Not (Test-Path c:\aws-workshop-init-script.log -PathType Leaf)) {
        Start-Sleep -Seconds 1
        ShowInitInProgressMessage "waiting for init script to start - $i"
        $i++
    }    
}

function WaitForMainInitScriptToComplete {
    while($true)
    {
        [int] $i = 1
        Get-Content c:\aws-workshop-init-script.log -tail 20000 -wait | `
        Select-Object { `
            ShowInitInProgressMessage "init script log line count $i" `
            # Start-Sleep -Seconds 1; `
            $_; `
        } | `
        Where-Object { `
            $i++; `
            $_ -match "Workshop dev box initialization has finished" `
        } | `
        ForEach-Object { break; }
    }
}

WaitForInitScriptLogFileCreation
WaitForMainInitScriptToComplete

Import-Module awspowershell.netcore

[string] $scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

# Include scripts with utility functions
Push-Location
Set-Location $scriptLocation
. ./git.ps1
. ./aws.ps1
. ./sys.ps1
Pop-Location

# Copy AWS CLI credentials to AWS SDK credentials store.
Set-AWSCredential -AccessKey (aws configure get aws_access_key_id --profile default) -SecretKey (aws configure get aws_secret_access_key --profile default) -StoreAs default
Set-AWSCredential -ProfileName default -Scope Global # This and preceding code needs to run outside of any function

[string] $awsRegion = GetDefaultAwsRegionName
Set-DefaultAWSRegion -Region $awsRegion -Scope Global

function InitUserSession {
    param(
        [string] $afterLoginScriptGitUrl,
        [string] $workDirectory
    )
        
    # Diagnostic output
    Write-Information "Retrieving current AWS SDK credentials `"default`" profile:"
    Get-AWSCredential -ProfileName default
    Write-Information "Set default AWS SDK region to `"$awsRegion`". Actual region is `"$(Get-DefaultAWSRegion)`"."

    # Invoke custom user script, if supplied
    Invoke-UserScript $afterLoginScriptGitUrl $workDirectory
}

function Invoke-UserScript {
    param (
        [string] $afterLoginScriptGitUrl,
        [string] $workDirectory
    )
    
    $afterLoginScriptGitUrl = CoalesceWithEnvVar $afterLoginScriptGitUrl "UNICORN_LAB_USER_SCRIPT_GIT_URL"
    if($afterLoginScriptGitUrl) {
        Push-Location
        [string] $projectDirectoryName = DirectoryNameFromGitHubUrl($afterLoginScriptGitUrl)
        [string] $userScriptDirectory = Join-Path (Resolve-Path $workDirectory) $projectDirectoryName "src"
        Set-Location $userScriptDirectory
        [string] $eventName = "on-after-user-login"
        Write-Information "$(Get-Date) Starting executing $eventName custom script from `"$userScriptDirectory/main.ps1`""
        & ./main.ps1 -eventName $eventName # Custom script entry point has to be "main.ps1"
        Write-Information "$(Get-Date) Completed executing $eventName custom script from `"$userScriptDirectory/main.ps1`""
        Pop-Location
    }
}

InitUserSession `
    -afterLoginScriptGitUrl $afterLoginScriptGitUrl `
    -workDirectory $workDirectory `
   *> C:\aws-workshop-user-session-init.log