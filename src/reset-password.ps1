# This script runs both at system startup and also on schedule
# to undo AWS EC2 instance initialization side effect that resets
# user password.
# Since the EC2 instance is used only for Labs/Workshops, where workshop
# attendees are given access to managed instances, the password needs
# to be well-known.

param (
    [string] $username = $null,
    [string] $secretword = "Passw0rd",
    [string] $isDebug = $false
)

[Security.SecureString] $securePassword = ConvertTo-SecureString $secretword -AsPlainText -Force

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
    }
    finally
    {
        $WhatIfPreference = $savedWhatIf
    }
}

if($IsWindows)
{
    setWindowsUserPassword -username $username -password $securePassword
}
