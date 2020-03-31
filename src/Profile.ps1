<#
Powershell profile implementing Set-AWSProfile and Set-AWSRegion commands keeping AWS CLI and AWS PowerShell Toolkit 
profiles and current region in sync. Lab boxes should have this script in there All Users/All Host PS profile 
(https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
#>

Write-Host "Initializing PowerShell profile. It may take a few seconds.."
$InformationPreference = "Continue"
Import-Module awspowershell.netcore

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
        if(-not $sdkProfileExists) {
            [string] $cliAccessKey = aws configure get aws_access_key_id --profile $Name
            if($cliAccessKey) {
                [string] $cliSecret = aws configure get aws_secret_access_key --profile $Name
                Set-AWSCredential -AccessKey $cliAccessKey -SecretKey $cliSecret -StoreAs $Name
                $sdkProfileExists = $true
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
