function GitCloneAndCheckout {
    param (
        [Parameter(mandatory=$true)] [string] $gitHubUrl,
        [Parameter(mandatory=$true)] [string] $projectDirectoryName, # must be a substring of $gitHubUrl
        [string] $gitBranchName = "master"
    )
    
    git clone $gitHubUrl
    Set-Location $projectDirectoryName
    git checkout $gitBranchName
    git pull
}