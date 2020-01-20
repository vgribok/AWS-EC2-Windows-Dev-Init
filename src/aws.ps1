Import-Module awspowershell.netcore # Todo: add this to system's PowerShell profile

function EnsureArray {
    param (
        $arg
    )
    
    if($arg -And -Not($arg -is [Array]))
    {
        $arg = @($arg)
    }

    return $arg
}

function InitWindowsEC2Instance 
{
    if(-not $IsWindows)
    {
        return
    }

    [string] $initScriptPath = Join-Path $env:ProgramData -ChildPath "Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1"

    try 
    {
        Write-Debug "Running EC2 initialization script"
        Invoke-Expression $initScriptPath
    }
    finally {
        Write-Debug "Done running EC2 initialization script"
    }
}

function InitializeEC2Instance 
{
    if($IsWindows)
    {
        InitWindowsEC2Instance
    }
}

function CreateAwsUser {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName,
        [bool] $useInstanceIdSuffix = $false,
        [bool] $isAdmin = $false
    )

    if($useInstanceIdSuffix)
    {
        [string] $instanceId = Get-EC2InstanceMetadata -category InstanceId # using EC2 instance ID as a username suffix
        $iamUserName += "-$instanceId"
    }

    New-IAMUser -UserName $iamUserName -ErrorAction SilentlyContinue
    Write-Host "Created AWS IAM user `"$iamUserName`""

    if($isAdmin)
    {
        Register-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
        Write-Host "Attached `"AdministratorAccess`" policy to IAM user `"$iamUserName`""
    }

    return $iamUserName
}


function GetDefaultAwsRegionName 
{
    $regionInfo = Get-EC2InstanceMetadata -category Region
    return $regionInfo.SystemName
}

function ConfigureCurrentAwsRegion {
    param (
        [string] $awsRegion
    )

    if(-Not $awsRegion)
    {
        $awsRegion = GetDefaultAwsRegionName
    }

    aws configure set region $awsRegion | Out-Host
    Initialize-AWSDefaultConfiguration -ProfileName default -Region $awsRegion

    Write-Host "Set current AWS region to `"$awsRegion`""
}

function ConfigureIamUserCredentialsOnTheSystem {
    param (
        [Parameter(mandatory=$true)] $accessKeyInfo,
        [string] $awsRegion
    )

    # Store credentials for AWS SDK and VS Toolkit
    Set-AWSCredential -AccessKey $accessKeyInfo.AccessKeyId -SecretKey $accessKeyInfo.SecretAccessKey -StoreAs default
    Write-Host "Set user `"$($awsAccessKeyInfo.UserName)`" (AccessKey `"$($accessKeyInfo.AccessKeyId)`") as current for AWS SDK and Visual Studio Toolkit"

    ConfigureCurrentAwsRegion($awsRegion)

    # Store credentials in ~/.aws "credentials" and "config" files
    aws configure set aws_access_key_id $accessKeyInfo.AccessKeyId | Out-Host
    aws configure set aws_secret_access_key $accessKeyInfo.SecretAccessKey | Out-Host
    aws configure set output json | Out-Host
    Write-Host "Set user `"$($awsAccessKeyInfo.UserName)`" (AccessKey `"$($accessKeyInfo.AccessKeyId)`") as current for `"aws`" cli"
}

function DeleteCfnStack {
    param (
        [Parameter(mandatory=$true)] [string] $cfnStackName
    )
    
    Remove-CFNStack -StackName $cfnStackName -Force
    Write-Host "Starting deletion of the `"$cfnStackName`" CloudFormation stack"
}

function DeleteCfnStacks {
    param (
        [Parameter(mandatory=$true)] [string[]] $cfnStackNames
    )
    
    foreach($cfnStackName in $cfnStackNames)
    {
        DeleteCfnStack($cfnStackName)
    }
}

function RemoveCodeCommitCredentialsForIamUser {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName
    )
    
    $codeCommitCredentials = Get-IAMServiceSpecificCredentialList -UserName $iamUserName -ServiceName codecommit.amazonaws.com
    $codeCommitCredentials = EnsureArray($codeCommitCredentials)

    foreach($cred in $codeCommitCredentials)
    {
        Remove-IAMServiceSpecificCredential -UserName $iamUserName -ServiceSpecificCredentialId $cred.ServiceSpecificCredentialId -Force
        Write-Host "Removed CodeCommit credentials for service user `"$($cred.ServiceSpecificCredentialId)`" (IAM user `"$iamUserName`")"
    }
}

function RemoveAccessKeyCredentialsFromTheSystem {
    if($IsWindows)
    {   # Removes AWS SDK and VS Toolkit credentials created by the Set-AWSCredential cmdlet
        [string] $awsSdkCredFilePath = "$($env:LOCALAPPDATA)/AWSToolkit/RegisteredAccounts.json"
        Remove-Item $awsSdkCredFilePath -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted AWS credentials file for AWS SDK: `"$awsSdkCredFilePath`""
    }
    # Remove credentials created using "aws configure" CLI
    Remove-Item -Recurse -Force "~/.aws" -ErrorAction SilentlyContinue
    Write-Host "Deleted `"~/.aws`" directory with AWS user credentials"

    refreshenv 
}

function RemoveAllAccessKeysForIamUser {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName
    )
    
    $accessKeyInfo = Get-IamAccessKey -UserName $iamUserName
    $accessKeyInfo = EnsureArray($accessKeyInfo)

    foreach ($accessKey in $accessKeyInfo) 
    {
        Remove-IAMAccessKey -UserName $iamUserName -AccessKeyId $accessKey.AccessKeyId -Force
        Write-Host "Removed AWS AccessKey `"$($accessKey.AccessKeyId)`" for IAM user `"$iamUserName`""
    }
}

function CreateAccessKeyForIamUser {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName,
        [bool] $removeAllExistingAccessKeys = $true
    )
   
    if($removeAllExistingAccessKeys)
    {
        RemoveAllAccessKeysForIamUser($iamUserName) # Remove existing AccessKeys if any were left, to not run into two AccessKeys limit
    }

    $awsAccessKeyInfo = New-IAMAccessKey $iamUserName
    Write-Host "Created new AWS AccessKey `"$($awsAccessKeyInfo.AccessKeyId)`" for IAM user `"$iamUserName`""

    return $awsAccessKeyInfo
}

function CreateCodeCommitGitCredentials {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName,
        [int] $codeCommitCredCreationDelaySeconds = 10 
        )

    RemoveCodeCommitCredentialsForIamUser($iamUserName)

    if($codeCommitCredCreationDelaySeconds -gt 0)
    {
        # It appears there's a race condition prevernting CodeCommit credentials 
        # from being created right after user is created
        Write-Host "Going to sleep for $codeCommitCredCreationDelaySeconds seconds before creating CodeCommit credentials to work around a race condition"
        Start-Sleep -Seconds $codeCommitCredCreationDelaySeconds 
    }

    $codeCommitCreds = New-IAMServiceSpecificCredential -UserName $iamUserName -ServiceName codecommit.amazonaws.com
    Write-Host "Created CodeCommit credentials with service user name `"$($codeCommitCreds.ServiceUserName)`" for IAM user `"$iamUserName`""

    return $codeCommitCreds
}
