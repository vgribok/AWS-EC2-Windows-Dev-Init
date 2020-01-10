function InitWindowsEC2Instance 
{
    if(-not $IsWindows)
    {
        return
    }

    [string] $initScriptPath = Join-Path $env:ProgramData -ChildPath "Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1"

    $savedExecutioPolicy = Get-ExecutionPolicy -Scope Process
    try 
    {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
        Write-Debug "Running EC2 initialization script"
        Invoke-Expression $initScriptPath
    }
    finally {
        Set-ExecutionPolicy -ExecutionPolicy $savedExecutioPolicy -Scope Process
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
        [string] $iamUserName,
        [System.Boolean] $isAdmin = $false
    )

    if(-Not $iamUserName)
    {
        [string] $instanceId = Get-EC2InstanceMetadata -category InstanceId # using EC2 instance ID as a username suffix
        $iamUserName = "temp-aws-lab-user-$instanceId"
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
