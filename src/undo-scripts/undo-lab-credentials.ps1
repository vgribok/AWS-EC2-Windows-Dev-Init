param(
    [string] $labName = "dotnet-cdk",
    [string] $tempIamUserPrefix = "temp-aws-lab-user"
)

Import-Module awspowershell.netcore

# Include scripts with utility functions
Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ../aws.ps1
Pop-Location

ConfigureCurrentAwsRegion -profileName $null

[string] $iamUserName = "$tempIamUserPrefix-$labName"

RemoveCodeCommitCredentialsForIamUser($iamUserName)
RemoveAccessKeyCredentialsFromTheSystem
RemoveAllAccessKeysForIamUser($iamUserName)

Unregister-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
Write-Information "Detached `"AdministratorAccess`" policy from IAM user `"$iamUserName`""

Remove-IAMUser -UserName $iamUserName -Force
Write-Information "Deleted IAM user `"$iamUserName`""