# Most scripts needed for the task at hand live in GitHub.
# This minimal, self-contained script, however, can be started on system startup.
# This script should be copied to target system separately from the rest,
# while the rest of the scripts will be bootsrapped from GitHub.

param(
    # Top group of parameters will change from one lab to another
    [string] $labName = "dotnet-cdk",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
    [string] $codeCommitRepoName = "Unicorn-Store-Sample-Git-Repo",

    # This group of parameters will likely stay unchanged
    [string] $scriptGitRepoUrl = "https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git",
    [string] $scriptDirectoryName = "AWS-EC2-Windows-Dev-Init",
    [string] $scriptBranchName = "master",
    [System.Boolean] $bootstrapDebug = $false
)
    
Write-Host "Debugging: $bootstrapDebug"

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))

if ($bootstrapDebug) 
{   # Execution path for when debugging on dev box
    & ./workshop-prep.ps1 `
        -isDebug $bootstrapDebug -labName $labName `
        -sampleAppGitHubUrl $sampleAppGitHubUrl -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileName $sampleAppSolutionFileName -codeCommitRepoName $codeCommitRepoName
}else
{   # Execution path for actual production use
    Set-Location "~"
    git clone $scriptGitRepoUrl $scriptDirectoryName | Out-Host
    Write-Host "Cloned `"$scriptGitRepoUrl`" remote Git repository to `"~/$scriptDirectoryName`" directory"

    Set-Location $scriptDirectoryName
    git checkout $scriptBranchName
    git pull
    Write-Host "Checled out and pulled `"$scriptBranchName`" branch"

    & ./src/workshop-prep.ps1 `
        -isDebug $bootstrapDebug -labName $labName `
        -sampleAppGitHubUrl $sampleAppGitHubUrl -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileName $sampleAppSolutionFileName -codeCommitRepoName $codeCommitRepoName
}

Pop-Location