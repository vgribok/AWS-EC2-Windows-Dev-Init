param(
    [string] $workDirectory = "~/AWS-workshop-assets",
    [string] $sampleAppGitRepoUrl, # UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL
    [string] $vsLicenseScriptGitHubUrl = "https://github.com/vgribok/VSCELicense.git"
)

Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ../sys.ps1
. ../git.ps1
Pop-Location

$sampleAppGitRepoUrl = CoalesceWithEnvVar $sampleAppGitRepoUrl "UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL"

# Delete directories created by cloning Git repos
[string[]] $gitUrls = $sampleAppGitRepoUrl, $vsLicenseScriptGitHubUrl

foreach ($gitUrl in $gitUrls) 
{
    if($gitUrl)
    {
        [string] $gitRepoDirectory = DirectoryNameFromGitHubUrl -gitHubUrl $gitUrl
        [string] $path = Join-Path $workDirectory $gitRepoDirectory
        if(Test-Path $path)
        {
            Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue
            Write-Information "Removed `"$path`" directory"
        }
    }
}

# Delete desktop shortcuts

if($IsWindows)
{
    [string[]] $desktopShortcuts = "Sample App.lnk", "Lab Guide.lnk", "Lab Guide.url"

    foreach($desktopShortcut in $desktopShortcuts)
    {
        $path = GetShortcutPath $desktopShortcut
        if(Test-Path $path)
        {
            Remove-Item $path
            Write-Information "Removed desktop shortcut `"$path`""
        }
    }
}