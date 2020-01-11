# Main script orchestrating system preparation flow.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    [string] $labName = "dotnet-cdk",
    [string] $workDirectory = "~/AWS-workshop-assets",
    [bool] $isDebug = $false,
    [string] $systemUserName = $null, # current/context user name will be used
    [string] $systemSecretWord = "Passw0rd",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $vsVersion = "VS2019",
    [string] $tempIamUserPrefix = "temp-aws-lab-user",
    [string] $codeCommitRepoName = "Unicorn-Store-Sample-Git-Repo"
)

Import-Module awspowershell.netcore

# Include scripts with utility functions
. ./git.ps1
. ./aws.ps1

# Retrieve Region name, like us-east-1, from EC2 instance metadata
$awsRegion = GetCurrentAwsRegionSystemName

Push-Location

mkdir $workDirectory -ErrorAction SilentlyContinue

# Get sample app source from GitHub
Set-Location $workDirectory
[string] $sampleAppDirectoryName = (GitCloneAndCheckout -gitHubUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName)
[string] $sampleAppPath = "$workDirectory/$sampleAppDirectoryName"

# Build sample app
Set-Location $sampleAppPath
dotnet build UnicornStore.sln -c DebugPostgres
git remote add aws "https://git-codecommit.$($awsRegion).amazonaws.com/v1/repos/$codeCommitRepoName" | Out-Host

# Update Visual Studio Community License
if($IsWindows)
{
    Set-Location $workDirectory
    [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -gitHubUrl $vsLicenseScriptGitHubUrl
    Import-Module "$workDirectory/$vsLicenseScriptDirectory"
    Set-VSCELicenseExpirationDate -Version $vsVersion
}

Pop-Location

# Re-setting EC2 instance to AWS defaults
InitializeEC2Instance

# Reset user password to counteract AWS initialization scrips
& ./reset-password.ps1 -username $systemUserName -password $systemSecretWord -isDebug $isDebug

# Create AWS IAM Admin user so we could use aws CLI and AWS VisualStudio toolkit
[string] $iamUserName = CreateAwsUser -iamUserName "$tempIamUserPrefix-$labName" -isAdmin $true

# Create access key so that user could be logged to enable AWS, CLI, PowerShell and AWS Tookit
$awsAccessKeyInfo = New-IAMAccessKey $iamUserName

# Create credentials for both AWS CLI and AWS SDK/VS Toolkit
ConfigureIamUserCredentialsOnTheSystem -accessKeyInfo $awsAccessKeyInfo -awsRegion $awsRegion
refreshenv

# Integrate Git and CodeCommit
New-IAMServiceSpecificCredential -UserName $iamUserName -ServiceName codecommit.amazonaws.com
ConfigureCodeCommit -gitUsername $iamUserName
