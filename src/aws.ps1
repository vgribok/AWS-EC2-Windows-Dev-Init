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

<#
function GenerateUserName {
    param (
        [Parameter(mandatory=$true)] [string] $prefix,
        [System.Boolean] $addInstanceIdSuffix = $false
    )
    
    [string] $instanceId = Get-EC2InstanceMetadata -category InstanceId # using EC2 instance ID as a username suffix
    $iamUserName = "temp-aws-lab-user-$instanceId"
}
#>
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

function GetCurrentAwsRegionSystemName 
{
    $regionInfo = Get-EC2InstanceMetadata -category Region
    return $regionInfo.SystemName
}

function ConfigureIamUserCredentialsOnTheSystem {
    param (
        [Parameter(mandatory=$true)] $accessKeyInfo,
        [string] $awsRegion
    )
    
    if(-Not $awsRegion)
    {
        $awsRegion = GetCurrentAwsRegionSystemName
    }

    # Store credentials for AWS SDK and VS Toolkit
    Set-AWSCredential -AccessKey $accessKeyInfo.AccessKeyId -SecretKey $accessKeyInfo.SecretAccessKey -StoreAs default
    Initialize-AWSDefaultConfiguration -ProfileName default -Region $awsRegion

    # Store credentials in ~/.aws "credentials" and "config" files
    aws configure set aws_access_key_id $accessKeyInfo.AccessKeyId | Out-Host
    aws configure set aws_secret_access_key $accessKeyInfo.SecretAccessKey | Out-Host
    aws configure set region $awsRegion | Out-Host
    aws configure set output json | Out-Host
}