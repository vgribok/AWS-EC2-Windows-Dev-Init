param(
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $sampleAppGitHubUrl = "https://github.com/vgribok/modernization-unicorn-store.git"
)

. ../git.ps1

Push-Location

Set-Location $workDirectory
[string] $sampleAppDirectoryName = DirectoryNameFromGitHubUrl -gitHubUrl $sampleAppGitHubUrl
Remove-Item -Recurse -Force $sampleAppDirectoryName -ErrorAction SilentlyContinue

Pop-Location