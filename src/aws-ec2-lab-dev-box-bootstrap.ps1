<#
A self-contained executable scripts that gets EC2 dev box initialization scripts from GitHub and runs them.
Feel free to modify this script on EC2 (not on your dev box!), at C:\aws-ec2-lab-dev-box-bootstrap.ps1 on Windows,
to get a sample app from a different remote Git location.
#> 

param(
    [string] $redirectToLog = $null,
    [bool] $bootstrapDebug = $false,

    # Top group of parameters will change from one lab to another
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git",
    [string] $sampleAppGitBranchName = "cdk-module-completed",
    [string] $sampleAppSolutionFileName = "UnicornStore.sln",
    [string] $cdkProjectDirPath = "./infra-as-code/CicdInfraAsCode/src", # put $null here to skip "cdk bootstrap" in the main script
    [string] $codeCommitRepoName = "Unicorn-Store-Sample-Git-Repo",

    # This group of parameters will likely stay unchanged
    [string] $scriptGitRepoUrl = "https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git",
    [string] $scriptDirectoryName = "AWS-EC2-Windows-Dev-Init",
    [string] $scriptBranchName = "master",
    [string] $scriptSourceDirectory = "./src"
)
    
Write-Information "Debugging: $bootstrapDebug"

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))

if (-Not $bootstrapDebug) 
{   
    Write-Information "Getting init scripts from `"$scriptGitRepoUrl`", branch `"$scriptBranchName`""

    # Get init scripts from GitHub
    Set-Location "~"
    git clone $scriptGitRepoUrl $scriptDirectoryName | Out-Host
    Write-Information "Cloned `"$scriptGitRepoUrl`" remote Git repository to `"~/$scriptDirectoryName`" directory"

    Set-Location $scriptDirectoryName
    git checkout $scriptBranchName
    git pull
    Write-Information "Checked out and pulled `"$scriptBranchName`" branch"
    Set-Location $scriptSourceDirectory
}

Write-Information "Invoking main workshop initialization script"
& ./workshop-prep.ps1 `
    -redirectToLog $redirectToLog `
    -isDebug $bootstrapDebug `
    -sampleAppGitHubUrl $sampleAppGitHubUrl -sampleAppGitBranchName $sampleAppGitBranchName `
    -sampleAppSolutionFileName $sampleAppSolutionFileName -cdkProjectDirPath $cdkProjectDirPath `
    -codeCommitRepoName $codeCommitRepoName

Pop-Location
