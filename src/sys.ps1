function setWindowsUserPassword {
    param (
        [string] $username,
        [Parameter(mandatory=$true)] [securestring] $password
    )

    if(-Not $username)
    {
        $username = $env:USERNAME
    }
    
    Write-Debug "Setting password for Windows user `"$username`""

    [System.Boolean] $savedWhatIf = $WhatIfPreference
    try {
        $WhatIfPreference = $isDebug
        Set-LocalUser -Name $username -Password $password
        Write-Host "Updated password for Windows user `"$username`""
    }
    finally
    {
        $WhatIfPreference = $savedWhatIf
    }
}

function SetLocalUserPassword {
    param (
        [string] $username = $null,
        [string] $secretword = "Passw0rd",
        [string] $isDebug = $false
    )
    
    [Security.SecureString] $securePassword = ConvertTo-SecureString $secretword -AsPlainText -Force
        
    if($IsWindows)
    {
        setWindowsUserPassword -username $username -password $securePassword
    }
}

function CleanupRetVal {
    param (
        $retVal
    )
    
    if($retVal -and ($retVal -is [Array]))
    {
        return $retVal[-1]
    }

    return $retVal
}
