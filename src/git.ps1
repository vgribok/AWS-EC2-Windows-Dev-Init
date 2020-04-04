<#
A component scripts to be included into your executable script.
Enables several high-level Git functions.
#>

function DirectoryNameFromGitHubUrl {
    param ([string] $gitHubUrl)

    [string] $gitUrlNoSuffix = if($gitHubUrl.ToLowerInvariant().EndsWith(".git")) { $gitHubUrl.Substring(0, $gitHubUrl.Length - ".git".Length) } else { $gitHubUrl }
    [string[]] $urlSegments = ([Uri]$gitUrlNoSuffix).Segments
    [string] $projectDirectoryName = $urlSegments[-1]
    return $projectDirectoryName
}

function GitCloneAndCheckout {
    param (
        [Parameter(mandatory=$true)] [string] $remoteGitUrl,
        [string] $gitBranchName = "master"
    )

    [string] $projectDirectoryName = DirectoryNameFromGitHubUrl($remoteGitUrl)

    git clone $remoteGitUrl | Out-Host # Piping output to Host removes retruned result pollution
    
    Push-Location
    Set-Location $projectDirectoryName

    [string ]$tagBranchName = $null
    [string] $gitTagPrefix = "tags/"
    
    if($gitBranchName.StartsWith($gitTagPrefix)) {
        $tagBranchName = "Tag_$($gitBranchName.Substring($gitTagPrefix.Length))"
        $tagBranchExists = git show-ref refs/heads/$tagBranchName
        if($tagBranchExists) {
            $gitBranchName = $tagBranchName
            git checkout $gitBranchName | Out-Host
        }else {
            git checkout -b $tagBranchName $gitBranchName  | Out-Host
        }
    }else {
        git checkout $gitBranchName | Out-Host
        git pull  | Out-Host
    }
    
    Pop-Location

    Write-Information "Cloned `"$remoteGitUrl`" Git repo to `"$projectDirectoryName`" directory and checked out & pulled `"$gitBranchName`" branch" 

    return $projectDirectoryName
}

function ConfigureGitSettings {
    param (
        [Parameter(Mandatory=$true)] [string] $gitUsername,
        [string] $projectRootDirPath,
        [string] $scope,
        [string] $gitUserEmail = "fakeuser@acme.com",
        [string] $helper,
        [bool] $useHttp = $true
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

    if($helper)
    {
        git config $scope credential.helper $helper | Out-Host
        Write-Information "Configured $($scope.Trim('-')) Git authentication helper for project `"$projectRootDirPath`""
    }

    if($useHttp)
    {
        git config $scope credential.UseHttpPath $useHttp | Out-Host
        Write-Information "Configured $($scope.Trim('-')) Git `"UseHttpPath=$useHttp`" for project `"$projectRootDirPath`""
    }

    git config $scope user.email $gitUserEmail | Out-Host
    git config $scope user.name $gitUsername | Out-Host

    Write-Information "Configured $($scope.Trim('-')) Git settings (user `"$gitUsername`", email `"$gitUserEmail`") for project `"$projectRootDirPath`""

    Pop-Location
}

function AddCodeCommitGitRemote {
    param (
        [string] $remoteName = "aws",
        [Parameter(Mandatory=$true)] [string] $awsRegion,
        [Parameter(Mandatory=$true)] [string] $codeCommitRepoName
    )
    
    $sampleAppPath = Get-Location

    git remote remove $remoteName | Out-Host
    git remote add $remoteName "https://git-codecommit.$($awsRegion).amazonaws.com/v1/repos/$codeCommitRepoName" | Out-Host
    Write-Information "Added `"$remoteName`" Git remote to the `"$sampleAppPath`" project"
}
