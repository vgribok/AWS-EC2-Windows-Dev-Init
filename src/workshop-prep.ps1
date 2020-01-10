# Main script orchestrating system preparation flow.
# Requirements: 
#   Git installed and configured
#   AWS Tools for PowerShell installed

param(
    [string] $workDirectory = "~/AWS-workshop-assets",
    [System.Boolean] $isDebug = $false,
    [string] $systemUserName = $null, # current/context user name will be used
    [string] $systemSecretWord = "Passw0rd",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git",
    [string] $vsVersion = "VS2019"
)

# Include scripts with utility functions
. ./git.ps1
. ./aws.ps1

Push-Location

#
mkdir $workDirectory -ErrorAction SilentlyContinue

# Get sample app source from GitHub
Set-Location $workDirectory
[string] $sampleAppDirectoryName = (GitCloneAndCheckout -gitHubUrl $sampleAppGitHubUrl -gitBranchName $sampleAppGitBranchName)

# Build sample app
Set-Location "$workDirectory/$sampleAppDirectoryName"
dotnet build UnicornStore.sln -c DebugPostgres

# Update Visual Studio Community License
if($IsWindows)
{
    Set-Location $workDirectory
    [string] $vsLicenseScriptDirectory = GitCloneAndCheckout -gitHubUrl $vsLicenseScriptGitHubUrl
    Import-Module "$workDirectory/$vsLicenseScriptDirectory"
    Set-VSCELicenseExpirationDate -Version $vsVersion
}

Pop-Location

# Re-setting EC2 instance
InitializeEC2Instance

# Reset user password to counteract AWS initialization scrips
& ./reset-password.ps1 -username $systemUserName -password $systemSecretWord -isDebug $isDebug

CreateAwsUser -isAdmin $true
