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
        [string] $awsRegion
    )

    if(-Not $awsRegion) {
        $awsRegion = GetDefaultAwsRegionName
    }

    aws configure set region $awsRegion | Out-Host
    Set-DefaultAWSRegion -Region $awsRegion -Scope Global

    Write-Information "Set current AWS region to `"$awsRegion`""
}

function ConfigureIamUserCredentialsOnTheSystem {
    param (
        [Parameter(mandatory=$true)] $accessKeyInfo,
        [string] $awsRegion
    )

    # Store credentials in ~/.aws "credentials" and "config" files
    aws configure set aws_access_key_id $accessKeyInfo.AccessKeyId | Out-Host
    aws configure set aws_secret_access_key $accessKeyInfo.SecretAccessKey | Out-Host
    aws configure set output json | Out-Host
    Write-Information "Set user `"$($awsAccessKeyInfo.UserName)`" (AccessKey `"$($accessKeyInfo.AccessKeyId)`") as current for `"aws`" cli"

    # Store credentials for AWS SDK and VS Toolkit
    #Set-AWSCredential -AccessKey $accessKeyInfo.AccessKeyId -SecretKey $accessKeyInfo.SecretAccessKey -StoreAs default
    Set-AWSCredential -ProfileName default -Scope Global
    Write-Information "Set `"default`" credetials profile as current for AWS SDK and Visual Studio Toolkit"

    ConfigureCurrentAwsRegion $awsRegion
}

function DeleteCfnStack {
    param (
        [Parameter(mandatory=$true)] [string] $cfnStackName
    )
    
    if($cfnStackName)
    {
        Remove-CFNStack -StackName $cfnStackName -Force
        Write-Information "Starting deletion of the `"$cfnStackName`" CloudFormation stack"
    }
}

function EnsureStringArray {
    param ($items)
    
    if(-Not $items) {
        return @()
    }
    $items = ($items -and ($items -is [string])) ? $items.Split(",") : $items
    return $items | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() }
}

function DeleteCfnStacks {
    param ($cfnStackNames)
    
    $cfnStackNames = EnsureStringArray($cfnStackNames)

    foreach($cfnStackName in $cfnStackNames) {
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

    # remove "default" SDK credentials profile
    Remove-AWSCredentialProfile -ProfileName default -Force
    Write-Information "Removed `"default`" SDK credentials profile"

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

function GetFirstRunningInstanceByName {
    param (
        [Parameter(mandatory=$true)] [string] $instanceName
    )
    
    $existingInstances = GetInstanceByName -ec2InstanceName $instanceName

    [int] $instanceStateRunning = 16

    foreach($instance in $existingInstances)
    {
        if($instance.State.Code -eq $instanceStateRunning)
        {
            return $instance
        }
    }

    return $null
}

<#
Starts sattelite Linux EC2 instance in the same vpc/subnet/securitygroup
#>
function StartLinuxDockerDaemonInstance {
    param (
        [Parameter(mandatory=$true)] [string] $linuxAmiId,
        [Parameter(mandatory=$true)] [Amazon.EC2.InstanceType] $instanceType
    )

    [string] $linuxInstanceName = MakeLinuxInstanceName

    $linuxInstance = GetFirstRunningInstanceByName($linuxInstanceName)
    if($linuxInstance)
    {
        return $linuxInstance
    }

    [string] $ec2Mac = Get-EC2InstanceMetadata -Path "/mac"
    [string] $subnetId = Get-EC2InstanceMetadata -Path "/network/interfaces/macs/$($ec2Mac)/subnet-id"
    [string] $securityGroupIds = Get-EC2InstanceMetadata -Path "/network/interfaces/macs/$($ec2Mac)/security-group-ids"

    $tagSpec = CreateEc2Tag -tagName "Name" -tagValue $linuxInstanceName

    $startedInstances = New-EC2Instance `
        -AssociatePublicIp $true `
        -ImageId $linuxAmiId `
        -SubnetId $subnetId `
        -InstanceType $instanceType `
        -SecurityGroupId $securityGroupIds `
        -TagSpecifications $tagSpec

    $linuxInstance = $startedInstances.Instances[0]

    Write-Information "Started instance $($linuxInstance.InstanceId) (`"$linuxInstanceName`")"

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

    [string] $dockerHostEnvVar = "DOCKER_HOST"

    if($instance)
    {
        [string] $dockerHostEnvVarValue = "tcp://$($instance.PrivateIpAddress):2375" #DOCKER_HOST="tcp://172.31.9.24:2375"
    }else {
        [string] $dockerHostEnvVarValue = $null
    }

    [System.Environment]::SetEnvironmentVariable($dockerHostEnvVar, $dockerHostEnvVarValue, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable($dockerHostEnvVar, $dockerHostEnvVarValue, [System.EnvironmentVariableTarget]::Process)

    Write-Information "Env var set: $dockerHostEnvVar=$($dockerHostEnvVarValue ?? "null")"
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

    if(-Not $ec2InstanceName)
    {
        return $null
    }

    $instance = GetInstanceByname -ec2InstanceName $ec2InstanceName
    if($instance)
    {
        Write-Information "Terminating instace `"$ec2InstanceName`" ($($instance.InstanceId))"
        return Remove-EC2Instance -InstanceId $instance.InstanceId -Force
    }
}

function DeleteEcrRepo {
    param (
        [Parameter(mandatory=$true)] [string] $ecrRepoName
    )
    
    if($ecrRepoName) {
        try {
            Remove-ECRRepository -RepositoryName $ecrRepoName -IgnoreExistingImages $true -Force -ErrorAction SilentlyContinue
            Write-Information "Removed ECR repository `"$ecrRepoName`""
        }catch {
            Write-Warning "ECR Repository `"$ecrRepoName`" was not deleted due to `"$PSItem`""
        }
    }
}

function DeleteEcrRepos {
    param ($ecrRepos)
    
    $ecrRepos = EnsureStringArray($ecrRepos)

    foreach($ecrRepo in $ecrRepos) {
        DeleteEcrRepo($ecrRepo)
    }
}

function ChangeVsToolkitCurrentRegion {
    param (
        [Parameter(mandatory=$true)] [string] $newRegion
    )

    if(-not $IsWindows) {
        return
    }

    [string] $vstoolkitsettingsFilePath = "$($env:LOCALAPPDATA)/AWSToolkit/MiscSettings.json"

    $vstoolkitsettings = Get-Content -Raw -Path $vstoolkitsettingsFilePath | ConvertFrom-Json
    [string] $prevRegion = $vstoolkitsettings.MiscSettings.lastselectedregion

    if($prevRegion -eq $newRegion) {
        return
    }

    $vstoolkitsettings.MiscSettings.lastselectedregion = $newRegion
    $vstoolkitsettings | ConvertTo-Json | Out-File $vstoolkitsettingsFilePath
    
    Write-Information "Changed AWS Visual Studio Toolkit region selection from `"$prevRegion`" to `"$newRegion`"."
}

#$hkw = TerminateInstanceByName(MakeLinuxInstanceName)
#SetDockerHostUserEnvVar

<#
# Starts Linux EC2 hosting Docker daemon
$linuxAmiId = "ami-089369d591ae701ba"
$instanceType = "t3a.small"
$linuxInstance = StartLinuxDockerDaemonInstance -linuxAmiId $linuxAmiId -instanceType $instanceType
# Points to remote Linux Docker host
SetDockerHostUserEnvVar -instance $linuxInstance
#>