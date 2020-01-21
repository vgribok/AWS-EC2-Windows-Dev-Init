<#
A self-contained executable scripts that gets EC2 dev box initialization scripts from GitHub and runs them.
Feel free to modify this script on EC2 (not on your dev box!), at C:\aws-ec2-lab-dev-box-bootstrap.ps1 on Windows,
to get a sample app from a different remote Git location.
#> 

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
    
Write-Information "Debugging: $bootstrapDebug"

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
    Write-Information "Cloned `"$scriptGitRepoUrl`" remote Git repository to `"~/$scriptDirectoryName`" directory"

    Set-Location $scriptDirectoryName
    git checkout $scriptBranchName
    git pull
    Write-Information "Checked out and pulled `"$scriptBranchName`" branch"

    & ./src/workshop-prep.ps1 `
        -isDebug $bootstrapDebug -labName $labName `
        -sampleAppGitHubUrl $sampleAppGitHubUrl -sampleAppGitBranchName $sampleAppGitBranchName `
        -sampleAppSolutionFileName $sampleAppSolutionFileName -codeCommitRepoName $codeCommitRepoName `
        *> "aws-workshop-init-script.log"
}

Pop-Location