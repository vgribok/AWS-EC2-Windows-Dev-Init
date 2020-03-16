# Main executable script orchestrating EC2 preparation flow for serving as Windows dev box.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    [string] $redirectToLog = $null,
    [string] $logFileName = "aws-workshop-init-script.log",

    # Top group of parameters will change from one lab to another
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module-completed",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
    [string] $cdkProjectDirPath = "./infra-as-code/CicdInfraAsCode/src", # Need just one CDK project path (in case there are more), from which to run "cdk bootstrap"
    [string] $codeCommitRepoName = "Unicorn-Store-Sample-Git-Repo",

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [bool] $isDebug = $false,
    [string] $systemUserName = $null, # current/context user name will be used
    [string] $systemSecretWord = "Passw0rd",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $vsVersion = "VS2019",
    [string] $tempIamUserPrefix = "temp-aws-lab-user",
    [int] $codeCommitCredCreationDelaySeconds = 10,
    [string] $awsRegion = $null # surfaced here for debugging purposes. Leave empty to let the value assigned from EC2 metadata
)

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)

function InitWorkshop {
    param (
        [string] $scriptLocation,
        [string] $sampleAppGitHubUrl,
        [string] $sampleAppGitBranchName,
        [string] $sampleAppSolutionFileName,
        [string] $cdkProjectDirPath,
        [string] $codeCommitRepoName,
    
        [string] $workDirectory,
        [bool] $isDebug,
        [string] $systemUserName,
        [string] $systemSecretWord,
        [string] $vsLicenseScriptGitHubUrl,
        [string] $vsVersion,
        [string] $tempIamUserPrefix,
        [int] $codeCommitCredCreationDelaySeconds,
        [string] $awsRegion
    )

    $now = get-date
    "AWS lab initialization scripts started on $now"

    Import-Module awspowershell.netcore # Todo: add this to system's PowerShell profile

    # Include scripts with utility functions
    Push-Location
    Set-Location $scriptLocation
    . ./git.ps1
    . ./aws.ps1
    . ./sys.ps1
    Pop-Location

    [string[]] $knownEnvVars = @("BOGUS_HKW", "UNICORN_LAB_INIT_SCRIPT_BRANCH", "LINUX_DOCKER_AMI", "LINUX_DOCKER_START", "LINUX_DOCKER_INSTANCE_SIZE")
    foreach ($envVarName in $knownEnvVars)
    {
        Write-Information "Env Var: $envVarName=$([System.Environment]::GetEnvironmentVariable($envVarName))"
    }

    # Reset user password to counteract AWS initialization scrips
    SetLocalUserPassword -username $systemUserName -password $systemSecretWord -isDebug $isDebug

    Push-Location

    mkdir $workDirectory -ErrorAction SilentlyContinue
    Write-Information "Created directory `"$workDirectory`""

    # Get sample app source from GitHub
    Set-Location $workDirectory
    $retVal = GitCloneAndCheckout -remoteGitUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName
    [string] $sampleAppDirectoryName = CleanupRetVal($retVal) 
    [string] $sampleAppPath = "$workDirectory/$sampleAppDirectoryName"

    # Update Visual Studio Community License
    if($IsWindows)
    {
        Write-Information "Bringing down stuff from `"$vsLicenseScriptGitHubUrl`""
        Set-Location $workDirectory
        [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -remoteGitUrl $vsLicenseScriptGitHubUrl
        Import-Module "$workDirectory/$vsLicenseScriptDirectory"
        Set-VSCELicenseExpirationDate -Version $vsVersion
    }

    # Re-setting EC2 instance to AWS defaults
    # This launches somewhat long-running AWS instance initialization scripts that gets stuck at 
    # DISKPART (scary! I know) for a little bit. Just let it finish, don't worry about it.
    # InitializeEC2Instance 

    # ALL AWS-RELATED ACTIONS SHOULD BE DONE BELOW THIS LINE
    foreach ($envVarName in $knownEnvVars)
    {
        Write-Information "Env Var: $envVarName=$([System.Environment]::GetEnvironmentVariable($envVarName))"
    }

    # Retrieve Region name, like us-east-1, from EC2 instance metadata
    if(-Not $awsRegion)
    {
        $awsRegion = GetDefaultAwsRegionName
    }
    for( ; -Not $awsRegion ; $awsRegion = GetDefaultAwsRegionName)
    {
        # no metadata, need to wait to let EC2 initialization script to finish
        Start-Sleep -s 5
    }
    Write-Information "Current AWS region metadata is determined to be `"$awsRegion`""

    # Build sample app
    Set-Location $sampleAppPath
    Write-Information "Starting building `"$sampleAppSolutionFileName`""
    dotnet build $sampleAppSolutionFileName -c DebugPostgres
    Write-Information "Finished building `"$sampleAppSolutionFileName`""

    # Adding "aws" as a Git remote, pointing to the CodeCommit repo in the current AWS account
    AddCodeCommitGitRemote -awsRegion $awsRegion -codeCommitRepoName $codeCommitRepoName

    if($cdkProjectDirPath)
    {
        # Prepare $cdkProjectDirPath for later use
        $cdkProjectDirPath = Resolve-Path $cdkProjectDirPath
    }

    Pop-Location

    # Create AWS IAM Admin user so we could use aws CLI and AWS VisualStudio toolkit
    [string] $iamUserName = MakeLabUserName -tempIamUserPrefix $tempIamUserPrefix -awsRegion $awsRegion
    CreateAwsUser -iamUserName $iamUserName -isAdmin $true

    # Create access key so that user could be logged to enable AWS, CLI, PowerShell and AWS Tookit
    $retVal = CreateAccessKeyForIamUser -iamUserName $iamUserName -removeAllExistingAccessKeys $true
    $awsAccessKeyInfo = CleanupRetVal($retVal)

    # Create credentials for both AWS CLI and AWS SDK/VS Toolkit
    ConfigureIamUserCredentialsOnTheSystem -accessKeyInfo $awsAccessKeyInfo -awsRegion $awsRegion
    refreshenv

    # Integrate Git and CodeCommit
    $ignore = CreateCodeCommitGitCredentials -iamUserName $iamUserName -codeCommitCredCreationDelaySeconds $codeCommitCredCreationDelaySeconds
    ConfigureGitSettings -gitUsername $iamUserName -projectRootDirPath $sampleAppPath -helper "!aws codecommit credential-helper $@"

    if($cdkProjectDirPath)
    {
        Write-Information  "Enabling usage of CDK in the `"$awsRegion`" region"
        Push-Location
        Set-Location $cdkProjectDirPath
        cdk bootstrap
        Write-Information "Enabled CDK for `"$awsRegion`""
        Pop-Location
    }

    $now = get-date
    "Workshop dev box initialization has finished on $now" 
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

    InitWorkshop `
        -scriptLocation $scriptLocation `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileName $sampleAppSolutionFileName `
        -cdkProjectDirPath $cdkProjectDirPath `
        -codeCommitRepoName $codeCommitRepoName `
        -workDirectory $workDirectory `
        -isDebug $isDebug `
        -systemUserName $systemUserName `
        -systemSecretWord $systemSecretWord `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -vsVersion $vsVersion `
        -tempIamUserPrefix $tempIamUserPrefix `
        -codeCommitCredCreationDelaySeconds $codeCommitCredCreationDelaySeconds `
        -awsRegion $awsRegion `
    *> $logFileLocation # redirecting all output to a log file
}else 
{
    Write-Information "Output is NOT redirected to the log file"
    
    InitWorkshop `
        -scriptLocation $scriptLocation `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileName $sampleAppSolutionFileName `
        -cdkProjectDirPath $cdkProjectDirPath `
        -codeCommitRepoName $codeCommitRepoName `
        -workDirectory $workDirectory `
        -isDebug $isDebug `
        -systemUserName $systemUserName `
        -systemSecretWord $systemSecretWord `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -vsVersion $vsVersion `
        -tempIamUserPrefix $tempIamUserPrefix `
        -codeCommitCredCreationDelaySeconds $codeCommitCredCreationDelaySeconds `
        -awsRegion $awsRegion
}
