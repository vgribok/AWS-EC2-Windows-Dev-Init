<#
Powershell profile implementing Set-AWSProfile and Set-AWSRegion commands keeping AWS CLI and AWS PowerShell Toolkit 
profiles and current region in sync. Lab boxes should have this script in there All Users/All Host PS profile 
(https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
#>

Write-Host "Initializing PowerShell profile. It may take a few seconds.."
$InformationPreference = "Continue"
Import-Module awspowershell.netcore

class AwsContext 
{
    [string] $AccountId
    [string] $AccessKey
    [string] $SecretKey
    [string] $Region
    [string] $Profile
    [bool] $WasCurrent

    AwsContext([string] $OptioinalProfileName) 
    {
        $this.Profile = $OptioinalProfileName ? $OptioinalProfileName : "default"
    }

    [void] SetCurrentRegion() {}
    [void] SetCurrentProfile() {}
}

class SdkContext : AwsContext 
{
    SdkContext([string] $OptioinalProfileName) : base($OptioinalProfileName) 
    {
        [string] $currentProfile = [SdkContext]::GetCurrentPorfile()
        $this.WasCurrent = $currentProfile -eq $this.Profile
        $this.Region = [SdkContext]::GetCurrentRegion()

        if($this.WasCurrent) {
            $this.AccountId = (Get-STSCallerIdentity).Account
            $credentials = (Get-AWSCredential).GetCredentials()
        }elseif (ProfileExists($currentProfile)) {
                $credentials = (Get-AWSCredential -ProfileName $currentProfile).GetCredentials()
        }

        if($credentials) {
            $this.AccessKey = $credentials.AccessKey
            $this.SecretKey = $credentials.SecretKey
        }
    }

    static [string] GetCurrentProfile() {
        return $StoredAWSCredentials ? $StoredAWSCredentials : "default"
    }

    static [string] GetCurrentRegion() {
        return Get-DefaultAWSRegion
    }

    static [bool] ProfileExists([string] $profile) {
        return (Get-AWSCredential -ListProfileDetail | Where-Object {$_.ProfileName -eq $profile}).Count -gt 0
    }

    static [void] SetCurrentRegion([string] $region) 
    {
        Set-DefaultAWSRegion $region -Scope Global
        Set-Variable -Name StoredAWSRegion -Value $StoredAWSRegion -Scope Global -Option None -Visibility Public # a work-around for the AWS PS Toolkit bug https://forums.aws.amazon.com/thread.jspa?threadID=259761
    }

    static [void] SetCurrentProfile([string] $profileName, [bool] $setEverywhere = $true) 
    {
        Set-AWSCredential -ProfileName $profileName # Sets surrent SDK/PS profile
        Set-Variable -Name StoredAWSCredentials -Value $StoredAWSCredentials -Scope Global -Option None -Visibility Public # a work-around for the AWS PS Toolkit bug https://forums.aws.amazon.com/thread.jspa?threadID=259761
    }

    [void] SetCurrentRegion() 
    {
        [SdkContext]::SetCurrentRegion($this.Region)
    }

    [void] SetCurrentProfile() 
    {
        [SdkContext]::SetCurrentProfile($this.Profile)
    }

    [void] SaveCredentialsAs([string] $profile) 
    {
        if($this.AccessKey -and $this.SecretKey) {
            Set-AWSCredential -AccessKey $this.AccessKey -SecretKey $this.SecretKey -StoreAs $profile
        }
    }
}

class CliContext : AwsContext {

    CliContext([string] $OptioinalProfileName) : base($OptioinalProfileName) 
    {
        [string] $currentProfile = [CliContext]::GetCurrentProfile()
        $this.WasCurrent = $currentProfile -eq $this.Profile

        if($this.WasCurrent) {
            $this.AccountId = [CliContext]::GetCurrentAccountId()
            $this.AccessKey = aws configure get aws_access_key_id
            $this.SecretKey = aws configure get aws_secret_access_key
            $this.Region = [CliContext]::GetCurrentRegion()
        } else {
            if(ProfileExists($OptioinalProfileName)) {
                $this.AccessKey = aws configure get aws_access_key_id --profile $this.Profile
                $this.SecretKey = aws configure get aws_secret_access_key --profile $this.Profile
                $this.Region = aws configure get region --profile $this.Profile
            }
        }
    }

    static [string] GetCurrentRegion() {
        return aws configure get region
    }

    static [string] GetCurrentProfile() {
        return $env:AWS_PROFILE ? $env:AWS_PROFILE : "default"
    }

    static [bool] ProfileExists([string] $profile) {
        return (aws configure list --profile $OptioinalProfileName).Count -gt 3
    }

    static [string] GetCurrentAccountId() 
    {
        return (aws sts get-caller-identity | ConvertFrom-Json).Account
    }

    static [void] SetCurrentProfile([string] $profileName, [bool] $setEverywhere = $true) 
    {
        $profileName = ($profileName -eq "default") ? "" : $profileName

        $env:AWS_PROFILE = $profileName
        if($setEverywhere) {
            [System.Environment]::SetEnvironmentVariable("AWS_PROFILE", $env:AWS_PROFILE, [System.EnvironmentVariableTarget]::User)            
        }
    }

    static [void] SetCurrentRegion([string] $region) 
    {
        if(-Not $region) { return }
        aws configure set region $region | Out-Host
    }

    [void] SetCurrentRegion() 
    {
        [CliContext]::SetCurrentRegion($this.Region)
    }

    [void] SetCurrentProfile() 
    {
        [CliContext]::SetCurrentProfile($this.Profile)
    }
}

function Get-CliContext([string] $optioinalProfileName) 
{
    return [CliContext]::new($optioinalProfileName)
}

function Get-SdkContext([string] $optioinalProfileName) 
{
    return [SdkContext]::new($optioinalProfileName)
}

function SyncCurrentCliAndSdkContexts() {
    [string] $sdkProfile = [SdkContext]::GetCurrentProfile()
    [string] $sdkRegion = [SdkContext]::GetCurrentRegion()

    if([CliContext]::ProfileExists($sdkProfile)) {
        $currentProfile = $sdkProfile
        [CliContext]::SetCurrentProfile($sdkProfile)
    }else {
        [string] $cliProfile = [CliContext]::GetCurrentProfile()
        $currentProfile = $cliProfile
        [SdkContext]::SetCurrentProfile($sdkProfile)
    }

    if($sdkRegion) {
        [CliContext]::SetCurrentRegion($sdkRegion)
    }else {
        $cliRegion = [CliContext]::GetCurrentRegion()
        if($cliRegion) {
            [SdkContext]::SetCurrentRegion($cliRegion)
        }
    }
}

# Write-Information "CLI Context"
# Get-CliContext
# Write-Information "CLI Context for default profile"
# Get-CliContext "default"
# Write-Information "CLI Context for mpsa profile"
# Get-CliContext "mpsa"
# Write-Information "CLI Context for bogus profile"
# Get-CliContext "bogus"
# Write-Information "------------------------------"

function Set-AWSRegion {
    param ([string] $Name = "us-east-1")

    aws configure set region $Name | Out-Host

	Initialize-AWSDefaultConfiguration -Region $Name
    Set-DefaultAWSRegion $Name -Scope Global
    Set-Variable -Name StoredAWSRegion -Value $StoredAWSRegion -Scope Global -Option None -Visibility Public # a work-around for the AWS PS Toolkit bug https://forums.aws.amazon.com/thread.jspa?threadID=259761
}

function Set-AWSProfile {
    param([string] $Name="default", [string] $Persist="true", [string] $defaultRegion = "us-east-2")

    [bool] $isDefaultProfile = $Name -eq "default"
    [bool] $awsCliProfileExists = (aws configure list --profile $Name).Count -gt 3

    $sdkCred = Get-AWSCredential $Name
    [bool] $sdkProfileExists = $false
    if($sdkCred) {
        $sdkCred = $sdkCred.GetCredentials()
        $sdkProfileExists = $true
    }

    if((-Not $awsCliProfileExists) -And (-Not $sdkProfileExists) -And (-Not $isDefaultProfile)) {
        Write-Warning "Profile `"$Name`" does not exist"
        return
    }

    if($awsCliProfileExists) {
        [string] $cliAccessKey = aws configure get aws_access_key_id --profile $Name
        if($cliAccessKey) {
            if((-not $sdkProfileExists) -or ($cliAccessKey -ne $sdkCred.AccessKey)) {
                [string] $cliSecret = aws configure get aws_secret_access_key --profile $Name
                if($cliSecret) {
                    Set-AWSCredential -AccessKey $cliAccessKey -SecretKey $cliSecret -StoreAs $Name
                    $sdkProfileExists = $true
                }
            }
        }
    }
    
    [string] $sdkRegion = ""

    if($sdkProfileExists) {
        Set-AWSCredential -ProfileName $Name # Sets surrent SDK/PS profile
        Set-AWSCredential -StoredCredentials $Name
        Set-Variable -Name StoredAWSCredentials -Value $StoredAWSCredentials -Scope Global -Option None -Visibility Public # a work-around for the AWS PS Toolkit bug https://forums.aws.amazon.com/thread.jspa?threadID=259761

        $sdkRegion = Get-DefaultAWSRegion
    }
    
    [string] $cliRegion = aws configure get region --profile $Name

    if((-Not $cliRegion) -And (-Not $sdkRegion)) {
        $cliRegion = $defaultRegion
        aws configure set region $cliRegion --profile $Name | Out-Host
    }

    if($cliRegion) {
		$sdkRegion = $cliRegion
		Initialize-AWSDefaultConfiguration -Region $sdkRegion
		Initialize-AWSDefaultConfiguration -ProfileName $Name -Region $sdkRegion
        Set-DefaultAWSRegion $sdkRegion -Scope Global
        Set-Variable -Name StoredAWSRegion -Value $StoredAWSRegion -Scope Global -Option None -Visibility Public # a work-around for the AWS PS Toolkit bug https://forums.aws.amazon.com/thread.jspa?threadID=259761
    }elseif ($sdkRegion) {
        $cliRegion = $sdkRegion # Since we are in PS, its Region setting overrides cli region
        aws configure set region $cliRegion --profile $Name | Out-Host
    }

    $env:AWS_PROFILE = ($isDefaultProfile) ? "" : $Name # Sets current CLI profile. Profile must exist, if not ""

    if($Persist -And ($Persist.ToLowerInvariant() -ne "false")) {
        [System.Environment]::SetEnvironmentVariable("AWS_PROFILE", $env:AWS_PROFILE, [System.EnvironmentVariableTarget]::User)
    }

    Write-Host "Set current AWS profile to `"$Name`""
}

#Debug
#Set-AWSProfile "default"

if($env:AWS_PROFILE) {
	Set-AWSProfile $env:AWS_PROFILE
}else {
	Set-AWSProfile "default"
}
function prompt 
{
    $savedLASTEXITCODE = $LASTEXITCODE

    $prompt = "PS"
	$needsAt = $false
    if ($null -ne $StoredAWSRegion) 
    { 
        $prompt += " $StoredAWSRegion" 
		$needsAt = $true
    }
    if ($null -ne $StoredAWSCredentials)
    {
		if($needsAt) {
			$prompt += "@"
		}
        $prompt += "$StoredAWSCredentials"
    }
    
    $prompt += " $($pwd.ProviderPath)>"

    $global:LASTEXITCODE = $savedLASTEXITCODE
    return $prompt
}
