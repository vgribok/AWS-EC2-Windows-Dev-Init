<#
A self-contained executable scripts that gets EC2 dev box initialization scripts from GitHub and runs them.
Feel free to modify this script on EC2 (not on your dev box!), at C:\aws-ec2-lab-dev-box-bootstrap.ps1 on Windows,
to get a sample app from a different remote Git location.
#> 

param(
    [string] $redirectToLog = $null,
    [bool] $bootstrapDebug = $false,

    # Top group of parameters will change from one lab to another
    [string] $labGuideUrl,
    [string] $sampleAppGitHubUrl,
    [string] $sampleAppGitBranchName,
    [string] $sampleAppSolutionFileDir,
    [string] $sampleAppSolutionFileName,
    [string] $cdkProjectDirPath, # put $null here to skip "cdk bootstrap" in the main script
    [string] $codeCommitRepoName,
    [string] $useDockerDamonLinuxEc2 = $null, # UNICORN_LAB_LINUX_DOCKER_START env var
    [string] $dockerDaemonLinuxAmi = $null, # UNICORN_LAB_LINUX_DOCKER_AMI env var
    [string] $dockerDaemonLinuxInstanceSize = $null, # UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE env var

    # This group of parameters will likely stay unchanged
    [string] $scriptGitRepoUrl = "https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git",
    [string] $scriptDirectoryName = "AWS-EC2-Windows-Dev-Init",
    [string] $scriptBranchName = $null,
    [string] $scriptSourceDirectory = "./src"
)
    
Write-Information "Debugging: $bootstrapDebug"

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))

if ($bootstrapDebug)
{
    $labGuideUrl = "./docs/en/index.html"
    $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git"
    $sampleAppGitBranchName = "cdk-module-completed"
    $sampleAppSolutionFileDir = "."
    $sampleAppSolutionFileName = "UnicornStore.sln"
    $cdkProjectDirPath = "./infra-as-code/CicdInfraAsCode/src" # put $null here to skip "cdk bootstrap" in the main script
    $codeCommitRepoName = "Unicorn-Store-Sample-Git-Repo"
    $useDockerDamonLinuxEc2 = $false
    $dockerDaemonLinuxAmi = $null
    $dockerDaemonLinuxInstanceSize = "t3a.small"
}else
{   
    if(-Not $scriptBranchName)
    {
        $scriptBranchName = $env:UNICORN_LAB_INIT_SCRIPT_BRANCH

        if(-Not $scriptBranchName)
        {
            $scriptBranchName = "master"
        }
    }

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
    -labGuideUrl $labGuideUrl `
    -redirectToLog $redirectToLog `
    -isDebug $bootstrapDebug `
    -sampleAppGitHubUrl $sampleAppGitHubUrl -sampleAppGitBranchName $sampleAppGitBranchName `
    -sampleAppSolutionFileDir $sampleAppSolutionFileDir -sampleAppSolutionFileName $sampleAppSolutionFileName -cdkProjectDirPath $cdkProjectDirPath `
    -codeCommitRepoName $codeCommitRepoName `
    -useDockerDamonLinuxEc2 $useDockerDamonLinuxEc2 -dockerDaemonLinuxAmi $dockerDaemonLinuxAmi -dockerDaemonLinuxInstanceSize $dockerDaemonLinuxInstanceSize

Pop-Location
