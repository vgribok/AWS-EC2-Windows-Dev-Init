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

function ConfigureCodeCommit {
    param (
        [Parameter(Mandatory=$true)] [string] $gitUsername,
        [string] $projectRootDirPath,
        [string] $scope,
        [string] $gitUserEmail = "fakeuser@codecommit.aws",
        [string] $helper = "!aws codecommit credential-helper $@"
    )
    
    Push-Location

    if($projectRootDirPath)
    {
        Set-Location $projectRootDirPath

        if(-Not $scope)
        {
            $scope = "--local"
        }
    }elseif(-Not $scope)
    {
        $scope = "--global"
    }

    git config $scope credential.helper $helper | Out-Host
    git config $scope credential.UseHttpPath true | Out-Host
    git config $scope user.email $gitUserEmail | Out-Host
    git config $scope user.name $gitUsername | Out-Host

    Pop-Location
}
