param(
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string[]] $gitUrls = @(
        "https://github.com/vgribok/modernization-unicorn-store.git",
        "https://github.com/vgribok/VSCELicense.git"
    )
)

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ../git.ps1
Pop-Location

foreach ($gitUrl in $gitUrls) 
{
    [string] $gitRepoDirectory = DirectoryNameFromGitHubUrl -gitHubUrl $gitUrl
    Remove-Item -Recurse -Force "$workDirectory/$gitRepoDirectory" -ErrorAction SilentlyContinue
}
