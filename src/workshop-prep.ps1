# Main script orchestrating system preparation flow.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    # Top group of parameters will change from one lab to another
    [string] $labName = "dotnet-cdk",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module",
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
    [int] $codeCommitCredCreationDelaySeconds = 10 
)

Import-Module awspowershell.netcore # Todo: add this to system's PowerShell profile

# Include scripts with utility functions
Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ./git.ps1
. ./aws.ps1
. ./sys.ps1
Pop-Location

# Retrieve Region name, like us-east-1, from EC2 instance metadata
[string] $awsRegion = GetDefaultAwsRegionName
Write-Host "Current AWS region metadata is determined to be `"$awsRegion`""

Push-Location

mkdir $workDirectory -ErrorAction SilentlyContinue
Write-Host "Creaeneccccbfnflucndirltbbhcuuicrvrdklbrjbltblbi
ted directory `"$workDirectory`""

# Get sample app source from GitHub
Set-Location $workDirectory
[string] $sampleAppDirectoryName = (GitCloneAndCheckout -gitHubUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName)[-1]
[string] $sampleAppPath = "$workDirectory/$sampleAppDirectoryName"

# Build sample app
Set-Location $sampleAppPath
Write-Host "Starting building `"$sampleAppSolutionFileName`""
dotnet build $sampleAppSolutionFileName -c DebugPostgres
Write-Host "Finished building `"$sampleAppSolutionFileName`""

git remote add aws "https://git-codecommit.$($awsRegion).amazonaws.com/v1/repos/$codeCommitRepoName" | Out-Host
Write-Host "Added `"aws`" Git remote to the `"$sampleAppPath`" project"

# Update Visual Studio Community License
if($IsWindows)
{
    Write-Host "Bringing down stuff from `"$vsLicenseScriptGitHubUrl`""
    Set-Location $workDirectory
    [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -gitHubUrl $vsLicenseScriptGitHubUrl
    Import-Module "$workDirectory/$vsLicenseScriptDirectory"
    Set-VSCELicenseExpirationDate -Version $vsVersion
}

Pop-Location

# Re-setting EC2 instance to AWS defaults
Write-Host "Starting standard AWS EC2 instance initialization"
InitializeEC2Instance
Write-Host "Finished standard AWS EC2 instance initialization"

# Reset user password to counteract AWS initialization scrips
SetLocalUserPassword -username $systemUserName -password $systemSecretWord -isDebug $isDebug

# Create AWS IAM Admin user so we could use aws CLI and AWS VisualStudio toolkit
[string] $iamUserName = "$tempIamUserPrefix-$labName"
CreateAwsUser -iamUserName $iamUserName -isAdmin $true

# Create access key so that user could be logged to enable AWS, CLI, PowerShell and AWS Tookit
$retVal = CreateAccessKeyForIamUser -iamUserName $iamUserName -removeAllExistingAccessKeys $true
$awsAccessKeyInfo = $retVal[-1]

# Create credentials for both AWS CLI and AWS SDK/VS Toolkit
ConfigureIamUserCredentialsOnTheSystem -accessKeyInfo $awsAccessKeyInfo -awsRegion $awsRegion
refreshenv

# Integrate Git and CodeCommit
CreateCodeCommitGitCredentials -iamUserName $iamUserName -codeCommitCredCreationDelaySeconds $codeCommitCredCreationDelaySeconds
ConfigureGitSettings -gitUsername $iamUserName -projectRootDirPath $sampleAppPath -helper "!aws codecommit credential-helper $@"
