# Main executable script orchestrating EC2 preparation flow for serving as Windows dev box.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    [string] $redirectToLog = $null,
    [string] $logFileName = "aws-workshop-init-script.log",

    # Top group of parameters will change from one lab to another
    [string] $labGuideUrl = $null, # UNICORN_LAB_GUIDE_URL env var, file:///C:/Users/Administrator/AWS-workshop-assets/modernization-unicorn-store/docs/en/index.html
    [string] $sampleAppGitHubUrl, # UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL env var
    [string] $sampleAppGitBranchName, # UNICORN_LAB_SAMPLE_APP_GIT_BRANCH env var
    [string] $sampleAppSolutionFileDir, # UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR env var
    [string] $sampleAppSolutionFileName, # UNICORN_LAB_SAMPLE_APP_SOLUTION_FILE env var
    [string] $sampleAppBuildConfiguration, # UNICORN_LAB_SAMPLE_APP_BUILD_CONFIG env var
    [string] $bootstrapCdk, # UNICORN_LAB_BOOTSTRAP_CDK env var
    [string] $codeCommitRepoName, # UNICORN_LAB_SAMPLE_APP_CODECOMMIT_REPO_NAME env var
    [string] $useDockerDamonLinuxEc2, # UNICORN_LAB_LINUX_DOCKER_START env var
    [string] $dockerDaemonLinuxAmi, # UNICORN_LAB_LINUX_DOCKER_AMI env var
    [string] $dockerDaemonLinuxInstanceSize, # UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE env var

    # This group of parameters are likely to stay unchanged from one lab to another
    [string] $workDirectory = "~/AWS-workshop-assets",
    [bool] $isDebug = $false,
    [string] $systemUserName = $null, # current/context user name will be used
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
        [string] $labGuideUrl,
        [string] $sampleAppGitHubUrl,
        [string] $sampleAppGitBranchName,
        [string] $sampleAppSolutionFileDir,
        [string] $sampleAppSolutionFileName,
        [string] $sampleAppBuildConfiguration,
        [string] $bootstrapCdk,
        [string] $codeCommitRepoName,
        [string] $useDockerDamonLinuxEc2,
        [string] $dockerDaemonLinuxAmi,
        [string] $dockerDaemonLinuxInstanceSize,
        
        [string] $workDirectory,
        [bool] $isDebug,
        [string] $systemUserName,
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
    . ./constants.ps1
    . ./git.ps1
    . ./aws.ps1
    . ./sys.ps1
    Pop-Location

    foreach ($envVarName in $knownEnvVars)
    {
        Write-Information "Env Var: $envVarName=$([System.Environment]::GetEnvironmentVariable($envVarName))"
    }

    $labGuideUrl = CoalesceWithEnvVar $labGuideUrl "UNICORN_LAB_GUIDE_URL" # Examples: "http://cdkworkshop.com", "./docs/en/index.html"
    $sampleAppGitHubUrl = CoalesceWithEnvVar $sampleAppGitHubUrl "UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL" # Example: "https://github.com/vgribok/modernization-unicorn-store.git"
    $sampleAppGitBranchName = CoalesceWithEnvVar $sampleAppGitBranchName "UNICORN_LAB_SAMPLE_APP_GIT_BRANCH" "master" # Example: "cdk-module-completed"
    $sampleAppSolutionFileDir = CoalesceWithEnvVar $sampleAppSolutionFileDir "UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR" "." # Relative path from git repo root to where solution is located
    $sampleAppSolutionFileName = CoalesceWithEnvVar $sampleAppSolutionFileName "UNICORN_LAB_SAMPLE_APP_SOLUTION_FILE" # Example: "UnicornStore.sln". Leave blank to build a directory instead of a file
    $sampleAppBuildConfiguration = CoalesceWithEnvVar $sampleAppBuildConfiguration "UNICORN_LAB_SAMPLE_APP_BUILD_CONFIG" "Debug"
    $bootstrapCdk = CoalesceWithEnvVar $bootstrapCdk "UNICORN_LAB_BOOTSTRAP_CDK" # Example: "yes"
    $codeCommitRepoName = CoalesceWithEnvVar $codeCommitRepoName "UNICORN_LAB_SAMPLE_APP_CODECOMMIT_REPO_NAME" "Unicorn-Store-Sample-Git-Repo" # Name of the CodeCommit repo where "git push aws" will push sample code
    $useDockerDamonLinuxEc2 = CoalesceWithEnvVar $useDockerDamonLinuxEc2 "UNICORN_LAB_LINUX_DOCKER_START" $null # Set to "true" to start remote Docker daemon instance
    $dockerDaemonLinuxAmi = CoalesceWithEnvVar $dockerDaemonLinuxAmi "UNICORN_LAB_LINUX_DOCKER_AMI" # Example: "ami-XXXXXXXXXXXX"
    $dockerDaemonLinuxInstanceSize = CoalesceWithEnvVar $dockerDaemonLinuxInstanceSize "UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE" "t3a.small"

    $awsRegion = Coalesce $awsRegion (GetDefaultAwsRegionName)
    Write-Information "Current AWS region is `"$awsRegion`""

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

    Push-Location

    # Launch satellite Linux isntance, if necessary, to host remote Docker daemon, enabling "docker build ." on this Windows system
    if($IsWindows -and $useDockerDamonLinuxEc2 -and $dockerDaemonLinuxAmi)
    {   # Start Docker remote daemon on the satellite Linux EC2 instance
        $linuxInstance = StartLinuxDockerDaemonInstance -linuxAmiId $dockerDaemonLinuxAmi -instanceType $dockerDaemonLinuxInstanceSize
        SetDockerHostUserEnvVar -instance $linuxInstance # Sets "DOCKER_HOST" env var
    }

    mkdir $workDirectory -ErrorAction SilentlyContinue
    Write-Information "Created directory `"$workDirectory`""

    # Update Visual Studio Community License
    if($IsWindows)
    {
        Write-Information "Bringing down stuff from `"$vsLicenseScriptGitHubUrl`""
        Set-Location $workDirectory
        [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -remoteGitUrl $vsLicenseScriptGitHubUrl
        Import-Module "$workDirectory/$vsLicenseScriptDirectory"
        Set-VSCELicenseExpirationDate -Version $vsVersion
    }

    if(IsWebUri $labGuideUrl)
    {   # If lab guide points to a web location, create desktop shortcut for it regardless whether sample app is used or not.
        CreateDesktopShortcut "Lab Guide" $labGuideUrl
    }

    if($bootstrapCdk) {
        [string] $awsAccount = (Get-STSCallerIdentity).Account
        [string] $awsEnvironment = "aws://$awsAccount/$awsRegion"
        Write-Information "Bootstrapping CDK for `"$awsEnvironment`""
        cdk bootstrap $awsEnvironment
    }

    if($sampleAppGitHubUrl)
    {
        # Get sample app source from GitHub
        Set-Location $workDirectory
        $retVal = GitCloneAndCheckout -remoteGitUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName
        [string] $sampleAppDirectoryName = CleanupRetVal($retVal) 
        [string] $sampleAppPath = Join-Path $workDirectory $sampleAppDirectoryName
        [string] $solutionDir = Join-Path $sampleAppPath $sampleAppSolutionFileDir
            
        # Build sample app
        Set-Location $solutionDir
        $solutionDir = $pwd
        [string] $solutionPath = $sampleAppSolutionFileName ? (Join-Path $solutionDir $sampleAppSolutionFileName) : $solutionDir

        Write-Information "Starting building `"$solutionPath`""
        if($sampleAppSolutionFileName)
        {   # Buld a project or a solution
            dotnet build $sampleAppSolutionFileName -c $sampleAppBuildConfiguration
        }else
        {   # Build whatever in the directory
            dotnet build -c $sampleAppBuildConfiguration
        }
        Write-Information "Finished building `"$solutionPath`""

        Set-Location $sampleAppPath

        if(-Not (IsWebUri $labGuideUrl))
        {
            CreateDesktopShortcut "Lab Guide" $labGuideUrl
        }
        CreateDesktopShortcut "Sample App" $solutionPath

        # Adding "aws" as a Git remote, pointing to the CodeCommit repo in the current AWS account
        AddCodeCommitGitRemote -awsRegion $awsRegion -codeCommitRepoName $codeCommitRepoName
        ConfigureGitSettings -gitUsername $iamUserName -projectRootDirPath $sampleAppPath -helper "!aws codecommit credential-helper $@"
    }

    Pop-Location

    # Set WS Visual Studio Toolkit region to the current
    ChangeVsToolkitCurrentRegion $awsRegion

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
        -labGuideUrl $labGuideUrl `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileDir $sampleAppSolutionFileDir `
        -sampleAppSolutionFileName $sampleAppSolutionFileName `
        -sampleAppBuildConfiguration $sampleAppBuildConfiguration `
        -bootstrapCdk $bootstrapCdk `
        -codeCommitRepoName $codeCommitRepoName `
        -useDockerDamonLinuxEc2 $useDockerDamonLinuxEc2 `
        -dockerDaemonLinuxAmi $dockerDaemonLinuxAmi `
        -dockerDaemonLinuxInstanceSize $dockerDaemonLinuxInstanceSize `
        `
        -workDirectory $workDirectory `
        -isDebug $isDebug `
        -systemUserName $systemUserName `
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
        -labGuideUrl $labGuideUrl `
        -sampleAppGitHubUrl $sampleAppGitHubUrl `
        -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileDir $sampleAppSolutionFileDir `
        -sampleAppSolutionFileName $sampleAppSolutionFileName `
        -sampleAppBuildConfiguration $sampleAppBuildConfiguration `
        -bootstrapCdk $bootstrapCdk `
        -codeCommitRepoName $codeCommitRepoName `
        -useDockerDamonLinuxEc2 $useDockerDamonLinuxEc2 `
        -dockerDaemonLinuxAmi $dockerDaemonLinuxAmi `
        -dockerDaemonLinuxInstanceSize $dockerDaemonLinuxInstanceSize `
        `
        -workDirectory $workDirectory `
        -isDebug $isDebug `
        -systemUserName $systemUserName `
        -vsLicenseScriptGitHubUrl $vsLicenseScriptGitHubUrl `
        -vsVersion $vsVersion `
        -tempIamUserPrefix $tempIamUserPrefix `
        -codeCommitCredCreationDelaySeconds $codeCommitCredCreationDelaySeconds `
        -awsRegion $awsRegion
}
