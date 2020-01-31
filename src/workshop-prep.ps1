# Main executable script orchestrating EC2 preparation flow for serving as Windows dev box.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    # Top group of parameters will change from one lab to another
    [string] $labName = "dotnet-cdk",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module-completed",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
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

$now = get-date
"AWS lab initialization scripts started on $now"

Import-Module awspowershell.netcore # Todo: add this to system's PowerShell profile

# Include scripts with utility functions
Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ./git.ps1
. ./aws.ps1
. ./sys.ps1
Pop-Location

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

Push-Location

mkdir $workDirectory -ErrorAction SilentlyContinue
Write-Information "Created directory `"$workDirectory`""

# Get sample app source from GitHub
Set-Location $workDirectory
$retVal = GitCloneAndCheckout -remoteGitUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName
[string] $sampleAppDirectoryName = CleanupRetVal($retVal) 
[string] $sampleAppPath = "$workDirectory/$sampleAppDirectoryName"

# Enable usage of CDK in the current region
cdk bootstrap
Write-Information "Enabled CDK for `"$awsRegion`""

# Build sample app
Set-Location $sampleAppPath
Write-Information "Starting building `"$sampleAppSolutionFileName`""
dotnet build $sampleAppSolutionFileName -c DebugPostgres
Write-Information "Finished building `"$sampleAppSolutionFileName`""

AddCodeCommitGitRemote -awsRegion $awsRegion -codeCommitRepoName $codeCommitRepoName

# Update Visual Studio Community License
if($IsWindows)
{
    Write-Information "Bringing down stuff from `"$vsLicenseScriptGitHubUrl`""
    Set-Location $workDirectory
    [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -remoteGitUrl $vsLicenseScriptGitHubUrl
    Import-Module "$workDirectory/$vsLicenseScriptDirectory"
    Set-VSCELicenseExpirationDate -Version $vsVersion
}

Pop-Location

# Re-setting EC2 instance to AWS defaults
# This launches somewhat long-running AWS instance initialization scripts that gets stuck at 
# DISKPART (scary! I know) for a little bit. Just let it finish, don't worry about it.
InitializeEC2Instance 

# Reset user password to counteract AWS initialization scrips
SetLocalUserPassword -username $systemUserName -password $systemSecretWord -isDebug $isDebug

# Create AWS IAM Admin user so we could use aws CLI and AWS VisualStudio toolkit
[string] $iamUserName = "$tempIamUserPrefix-$labName"
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

$now = get-date
"Workshop dev box initialization has finished on $now"
