param(
    [string] $tempIamUserPrefix = "temp-aws-lab-user"
)

Import-Module awspowershell.netcore

# Include scripts with utility functions
Push-Location
Set-Location ([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path))
. ../aws.ps1
Pop-Location

$awsRegion = GetDefaultAwsRegionName

ConfigureCurrentAwsRegion $awsRegion

[string] $iamUserName = MakeLabUserName -tempIamUserPrefix $tempIamUserPrefix -awsRegion $awsRegion

RemoveCodeCommitCredentialsForIamUser($iamUserName)
RemoveAccessKeyCredentialsFromTheSystem
RemoveAllAccessKeysForIamUser($iamUserName)

Unregister-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
Write-Information "Detached `"AdministratorAccess`" policy from IAM user `"$iamUserName`""

Remove-IAMUser -UserName $iamUserName -Force
Write-Information "Deleted IAM user `"$iamUserName`""

# Re-setting EC2 instance to AWS defaults
# This launches somewhat long-running AWS instance initialization scripts that gets stuck at 
# DISKPART (scary! I know) for a little bit. Just let it finish, don't worry about it.
InitializeEC2Instance 

ConfigureCurrentAwsRegion $awsRegion
