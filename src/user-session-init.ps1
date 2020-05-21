Import-Module awspowershell.netcore

[string] $scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

function InitUserSession {
    param(
        [string] $afterLoginScriptGitUrl,
        [string] $workDirectory = "~/AWS-workshop-assets"
    )

    # Include scripts with utility functions
    Push-Location
    Set-Location $scriptLocation
    . ./git.ps1
    . ./aws.ps1
    . ./sys.ps1
    Pop-Location

    # Copy AWS CLI credentials to AWS SDK credentials store
    Set-AWSCredential -AccessKey (aws configure get aws_access_key_id --profile default) -SecretKey (aws configure get aws_secret_access_key --profile default) -StoreAs default
    
    # Diagnostic output
    Write-Information "Retrieving current AWS SDK credentials `"default`" profile:"
    Get-AWSCredential -ProfileName default

    $afterLoginScriptGitUrl = CoalesceWithEnvVar $afterLoginScriptGitUrl "UNICORN_LAB_AFTER_LOGIN_SCRIPT_GIT_URL"
    if($afterLoginScriptGitUrl) {
        [string] $projectDirectoryName = DirectoryNameFromGitHubUrl($afterLoginScriptGitUrl)
        [string] $userScriptDirectory = [System.IO.Path]::Join($workDirectory, $projectDirectoryName, "/src") # Custom script should reside in the /src directory relative to the repo root
        Push-Location
        Set-Location $userScriptDirectory
        Write-Information "$(Get-Date) Starting executing on-login custom script from `"$userScriptDirectory/main.ps1`""
        & ./main.ps1 # Custom script entry point has to be "main.ps1"
        Write-Information "$(Get-Date) Completed executing on-login custom script from `"$userScriptDirectory/main.ps1`""
        Pop-Location
    }
}

InitUserSession `
    -afterLoginScriptGitUrl $afterLoginScriptGitUrl `
    -workDirectory $workDirectory #`
#    *> C:\aws-workshop-user-session-init.log