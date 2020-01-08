# Main script implementing with system preparation flow.
# 

# Requirements: 
#   Git installed and configured
param(
    [System.Boolean] $isDebug = $false,
    [string] $systemUserName = $null,
    [string] $systemSecretWord = "Passw0rd",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppDirectoryName = "modernization-unicorn-store",
    [string] $sampleAppGitBranchName = "cdk-module",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln"
)

. ./git.ps1

& ./reset-password.ps1 -username $systemUserName -password $systemSecretWord -isDebug $isDebug

Push-Location
Set-Location ~
GitCloneAndCheckout -gitHubUrl $sampleAppGitHubUrl -projectDirectoryName $sampleAppDirectoryName -gitBranchName $sampleAppGitBranchName
Set-Location "~/$sampleAppDirectoryName"
dotnet build UnicornStore.sln -c DebugPostgres
Pop-Location