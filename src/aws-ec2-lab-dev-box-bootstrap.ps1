# Most scripts needed for the task at hand live in GitHub.
# This minimal script, however, can be started on system startup.
# This script should be copied to target system separately from teh rest,
# while the rest of the scripts will be bootsrapped from GitHub.

param(
    [string] $scriptGitRepoUrl = "https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git",
    [string] $scriptDirectoryName = "AWS-EC2-Windows-Dev-Init",
    [string] $scriptBranchName = "master",
    [System.Boolean] $bootstrapDebug = $false
)
    
Write-Debug "Debugging: $bootstrapDebug"
Write-Debug "Will checkout `"$scriptGitRepoUrl`", branch `"$scriptBranchName`""

if ($bootstrapDebug) 
{   # Execution path for when debugging on dev box
    & ./workshop-prep.ps1 -isDebug $bootstrapDebug
}else
{   # Execution path for actual production use
    Set-Location "~"
    git clone $scriptGitRepoUrl $scriptDirectoryName | Out-Host
    Set-Location $scriptDirectoryName
    git checkout $scriptBranchName
    git pull
    & ./src/workshop-prep.ps1 -isDebug $bootstrapDebug
}
