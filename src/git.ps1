function DirectoryNameFromGitHubUrl([string] $gitHubUrl)
{
    [string] $gitUrlNoSuffix = if($gitHubUrl.ToLowerInvariant().EndsWith(".git")) { $gitHubUrl.Substring(0, $gitHubUrl.Length - ".git".Length) } else { $gitHubUrl }
    [string[]] $urlSegments = ([Uri]$gitUrlNoSuffix).Segments
    [string] $projectDirectoryName = $urlSegments[-1]
    return $projectDirectoryName
}

function GitCloneAndCheckout {
    param (
        [Parameter(mandatory=$true)] [string] $gitHubUrl,
        [string] $gitBranchName = "master"
    )

    [string] $projectDirectoryName = DirectoryNameFromGitHubUrl($gitHubUrl)

    git clone $gitHubUrl | Out-Host # Piping output to Host removes retruned result pollution
    
    Push-Location
    Set-Location $projectDirectoryName
    git checkout $gitBranchName | Out-Host
    git pull | Out-Host
    Pop-Location

    return $projectDirectoryName
}
