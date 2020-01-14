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

    $savedErrorActionPref = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        # It looks like AWS PowerShell cmdlets do not support "-ErrorAction" parameter
        New-IAMUser -UserName $iamUserName -ErrorAction SilentlyContinue
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPref
    }

    if($isAdmin)
    {
        Register-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
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
        $awsRegion = GetCurrentAwsRegionSystemName
    }

    Initialize-AWSDefaultConfiguration -ProfileName default -Region $awsRegion
    aws configure set region $awsRegion | Out-Host
}

function ConfigureIamUserCredentialsOnTheSystem {
    param (
        [Parameter(mandatory=$true)] $accessKeyInfo,
        [string] $awsRegion
    )

    ConfigureCurrentAwsRegion($awsRegion)

    # Store credentials for AWS SDK and VS Toolkit
    Set-AWSCredential -AccessKey $accessKeyInfo.AccessKeyId -SecretKey $accessKeyInfo.SecretAccessKey -StoreAs default

    # Store credentials in ~/.aws "credentials" and "config" files
    aws configure set aws_access_key_id $accessKeyInfo.AccessKeyId | Out-Host
    aws configure set aws_secret_access_key $accessKeyInfo.SecretAccessKey | Out-Host
    aws configure set output json | Out-Host
}

function DeleteCfnStack {
    param (
        [Parameter(mandatory=$true)] [string] $cfnStackName
    )
    
    Remove-CFNStack -StackName $cfnStackName -Force
    Write-Debug "Startign deletion of the `"$cfnStackName`" CloudFormation stack"
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
    }
}

function RemoveAccessKeyCredentialsFromTheSystem {
    if($IsWindows)
    {   # Removes AWS SDK and VS Toolkit credentials created by the Set-AWSCredential cmdlet
        Remove-Item "$($env:LOCALAPPDATA)/AWSToolkit/RegisteredAccounts.json" -Force -ErrorAction SilentlyContinue
    }
    # Remove credentials created using "aws configure" CLI
    Remove-Item -Recurse -Force "~/.aws" -ErrorAction SilentlyContinue
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
    }
}