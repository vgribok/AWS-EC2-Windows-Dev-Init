param(
    [string] $afterLoginScriptGitUrl,
    [string] $workDirectory = "~/AWS-workshop-assets"
)

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
Write-Information "Set `"default`" credetials profile as current for AWS SDK and Visual Studio Toolkit"

[string] $awsRegion = GetDefaultAwsRegionName
Set-DefaultAWSRegion -Region $awsRegion -Scope Global
Write-Information "Set default AWS SDK region to `"$(Get-DefaultAWSRegion)`""

function InitUserSession {
    param(
        [string] $afterLoginScriptGitUrl,
        [string] $workDirectory
    )
        
    # Diagnostic output
    Write-Information "Retrieving current AWS SDK credentials `"default`" profile:"
    Get-AWSCredential -ProfileName default

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
        [string] $userScriptDirectory = [System.IO.Path]::Join((Resolve-Path $workDirectory), $projectDirectoryName, "src")
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