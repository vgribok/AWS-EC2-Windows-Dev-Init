<#
A component scripts to be included into your executable script.
Enables several high-level AWS functions.
#>

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
        Write-Information "Running EC2 initialization script"
        Invoke-Expression $initScriptPath | Out-Null
    }
    finally {
        Write-Information "Done running EC2 initialization script"
    }
}

function InitializeEC2Instance 
{
    if($IsWindows)
    {
        InitWindowsEC2Instance
    }
}

function GetInstanceName()
{
    [string] $instanceId = Get-EC2InstanceMetadata -category InstanceId
    if(!$instanceId)
    {
        $instanceId = $env:HOSTNAME
    }
    if(!$instanceId)
    {
        $instanceId = $env:COMPUTERNAME
    }
    return $instanceId
}

function MakeLabUserName {
    param (
        [Parameter(mandatory=$true)] [string] $tempIamUserPrefix,
        [Parameter(mandatory=$true)] [string] $awsRegion
    )
    [string] $instanceId = GetInstanceName # using EC2 instance ID as a username suffix
    [string] $iamUserName = "$tempIamUserPrefix-$awsRegion-$instanceId" # Should not exceed 64 chars

     # Should not exceed 64 chars
    return $iamUserName
}

function CreateAwsUser {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName,
        [bool] $isAdmin = $false
    )

    New-IAMUser -UserName $iamUserName -ErrorAction SilentlyContinue
    Write-Information "Created AWS IAM user `"$iamUserName`""

    if($isAdmin)
    {
        Register-IAMUserPolicy -UserName $iamUserName -PolicyArn "arn:aws:iam::aws:policy/AdministratorAccess"
        Write-Information "Attached `"AdministratorAccess`" policy to IAM user `"$iamUserName`""
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
        [string] $awsRegion,
        [string] $profileName = "default"
    )

    if(-Not $awsRegion)
    {
        $awsRegion = GetDefaultAwsRegionName
    }

    aws configure set region $awsRegion | Out-Host
    if($profileName)
    {
        Initialize-AWSDefaultConfiguration -ProfileName $profileName -Region $awsRegion
    }else 
    {
        Initialize-AWSDefaultConfiguration -Region $awsRegion
    }

    Write-Information "Set current AWS region to `"$awsRegion`""
}

function ConfigureIamUserCredentialsOnTheSystem {
    param (
        [Parameter(mandatory=$true)] $accessKeyInfo,
        [string] $awsRegion
    )

    # Store credentials for AWS SDK and VS Toolkit
    Set-AWSCredential -AccessKey $accessKeyInfo.AccessKeyId -SecretKey $accessKeyInfo.SecretAccessKey -StoreAs default
    Write-Information "Set user `"$($awsAccessKeyInfo.UserName)`" (AccessKey `"$($accessKeyInfo.AccessKeyId)`") as current for AWS SDK and Visual Studio Toolkit"

    ConfigureCurrentAwsRegion($awsRegion)

    # Store credentials in ~/.aws "credentials" and "config" files
    aws configure set aws_access_key_id $accessKeyInfo.AccessKeyId | Out-Host
    aws configure set aws_secret_access_key $accessKeyInfo.SecretAccessKey | Out-Host
    aws configure set output json | Out-Host
    Write-Information "Set user `"$($awsAccessKeyInfo.UserName)`" (AccessKey `"$($accessKeyInfo.AccessKeyId)`") as current for `"aws`" cli"
}

function DeleteCfnStack {
    param (
        [Parameter(mandatory=$true)] [string] $cfnStackName
    )
    
    Remove-CFNStack -StackName $cfnStackName -Force
    Write-Information "Starting deletion of the `"$cfnStackName`" CloudFormation stack"
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
        Write-Information "Removed CodeCommit credentials for service user `"$($cred.ServiceSpecificCredentialId)`" (IAM user `"$iamUserName`")"
    }
}

function RemoveAccessKeyCredentialsFromTheSystem {
    if($IsWindows)
    {   # Removes AWS SDK and VS Toolkit credentials created by the Set-AWSCredential cmdlet
        [string] $awsSdkCredFilePath = "$($env:LOCALAPPDATA)/AWSToolkit/RegisteredAccounts.json"
        Remove-Item $awsSdkCredFilePath -Force -ErrorAction SilentlyContinue
        Write-Information "Deleted AWS credentials file for AWS SDK: `"$awsSdkCredFilePath`""
    }
    # Remove credentials created using "aws configure" CLI
    Remove-Item -Recurse -Force "~/.aws" -ErrorAction SilentlyContinue
    Write-Information "Deleted `"~/.aws`" directory with AWS user credentials"

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
        Write-Information "Removed AWS AccessKey `"$($accessKey.AccessKeyId)`" for IAM user `"$iamUserName`""
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
    Write-Information "Created new AWS AccessKey `"$($awsAccessKeyInfo.AccessKeyId)`" for IAM user `"$iamUserName`""

    return $awsAccessKeyInfo
}

function CreateCodeCommitGitCredentials {
    param (
        [Parameter(mandatory=$true)] [string] $iamUserName,
        [int] $codeCommitCredCreationDelaySeconds = 10 
        )

    if($codeCommitCredCreationDelaySeconds -gt 0)
    {
        # It appears there's a race condition prevernting CodeCommit credentials 
        # from being created right after user is created
        Write-Information "Going to sleep for $codeCommitCredCreationDelaySeconds seconds before creating CodeCommit credentials to work around a race condition"
        Start-Sleep -Seconds $codeCommitCredCreationDelaySeconds 
    }

    RemoveCodeCommitCredentialsForIamUser($iamUserName)

    $codeCommitCreds = New-IAMServiceSpecificCredential -UserName $iamUserName -ServiceName codecommit.amazonaws.com
    Write-Information "Created CodeCommit credentials with service user name `"$($codeCommitCreds.ServiceUserName)`" for IAM user `"$iamUserName`""

    return $codeCommitCreds
}

param(
    [string] $linuxAmiId = "ami-089369d591ae701ba",
    [Amazon.EC2.InstanceType] $instanceType = "t3a.medium"
)

function MakeLinuxInstanceName {
    [string] $windowsInstanceId = Get-EC2InstanceMetadata -category InstanceId
    return "Docker daemon for $windowsInstanceId"
}

function CreateEc2Tag {
    param (
        [Parameter(mandatory=$true)] [string] $tagName,
        [Parameter(mandatory=$true)] [string] $tagValue,
        [Amazon.EC2.Model.TagSpecification] $tagSpec = $null
    )
    
    if(-Not $tagSpec)
    {
        $tagSpec = New-Object Amazon.EC2.Model.TagSpecification
    }
    $tagSpec.ResourceType = [Amazon.EC2.ResourceType]::Instance

    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = $tagName
    $tag.Value = $tagValue

    $tagSpec.Tags.Add($tag)

    return $tagSpec
}

<#
Starts sattelite Linux EC2 instance in the same vpc/subnet/securitygroup
#>
function StartLinuxDockerDaemonInstance {
    param (
        [Parameter(mandatory=$true)] [string] $linuxAmiId,
        [Parameter(mandatory=$true)] [Amazon.EC2.InstanceType] $instanceType
    )

    [string] $ec2Mac = Get-EC2InstanceMetadata -Path "/mac"
    [string] $subnetId = Get-EC2InstanceMetadata -Path "/network/interfaces/macs/$($ec2Mac)/subnet-id"
    [string] $securityGroupIds = Get-EC2InstanceMetadata -Path "/network/interfaces/macs/$($ec2Mac)/security-group-ids"

    $tagSpec = CreateEc2Tag -tagName "Name" -tagValue (MakeLinuxInstanceName)

    $linuxInstance = New-EC2Instance `
        -ImageId $linuxAmiId `
        -SubnetId $subnetId `
        -InstanceType $instanceType `
        -SecurityGroupId $securityGroupIds `
        -TagSpecifications $tagSpec

    return $linuxInstance
}

<#
Points Docker client to an EC2 instance by setting DOCKER_HOST environment variable.
If instance is $null, removes DOCKER_HOST environment variable.
#>
function SetDockerHostUserEnvVar {
    param (
        $instance
    )

    if($instance)
    {
        [string] $dockerHostEnvVarValue = "tcp://$($instance.PrivateIpAddress):2375" #DOCKER_HOST="tcp://172.31.9.24:2375"
    }else {
        [string] $dockerHostEnvVarValue = $null
    }

    [System.Environment]::SetEnvironmentVariable("DOCKER_HOST", $dockerHostEnvVarValue, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable("DOCKER_HOST", $dockerHostEnvVarValue, [System.EnvironmentVariableTarget]::Process)
}

function GetInstanceByName {
    param (
        [Parameter(mandatory=$true)] [string] $ec2InstanceName
    )

    $searchFor =@(
    @{
        name = 'tag:Name'
        values = $ec2InstanceName
    })
    $instance = Get-EC2Instance -Filter $searchFor
    return $instance.Instances
}

function TerminateInstanceByName {
    param (
        [Parameter(mandatory=$true)] [string] $ec2InstanceName
    )

    $instance = GetInstanceByname -ec2InstanceName $ec2InstanceName
    if($instance)
    {
        return Remove-EC2Instance -InstanceId $instance.InstanceId -Force
    }
}

<#
$hkw = TerminateInstanceByName(MakeLinuxInstanceName)
SetDockerHostUserEnvVar
#>

<#
# Starts Linux EC2 hosting Docker daemon
$linuxInstance = StartLinuxDockerDaemonInstance -linuxAmiId $linuxAmiId -instanceType $instanceType

# Points to remote Linux Docker host
SetDockerHostUserEnvVar -instance $linuxInstance.Instances[0]
#>