# Most scripts needed for the task at hand live in GitHub.
# This minimal script, however, can be started on system startup.
# This script should be copied to target system separately from teh rest,
# while the rest of the scripts will be bootsrapped from GitHub.

param(
    [string] $scriptGitRepoUrl = "https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git",
    [string] $scriptBranchName = "master",
    [System.Boolean] $bootstrapDebug = $false
)
    
Write-Debug "Debugging: $bootstrapDebug"
Write-Debug "Will checkout `"$scriptGitRepoUrl`", branch `"$scriptBranchName`""

if ($bootstrapDebug) 
{
    & ./workshop-prep.ps1 -isDebug $bootstrapDebug
}else
{
    Set-Location "~"
    git clone $scriptGitRepoUrl
    git checkout $scriptBranchName
    & ~/AWS-EC2-Windows-Dev-Init/src/workshop-prep.ps1 -isDebug $bootstrapDebug
}