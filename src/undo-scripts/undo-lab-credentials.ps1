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

ConfigureCurrentAwsRegion

[string] $iamUserName = "$tempIamUserPrefix-$labName"

RemoveCodeCommitCredentialsForIamUser($iamUserName)
RemoveAccessKeyCredentialsFromTheSystem
RemoveAllAccessKeysForIamUser($iamUserName)
Unregister-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
Remove-IAMUser -UserName $iamUserName -Force


