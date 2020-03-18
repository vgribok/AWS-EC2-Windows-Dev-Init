<#
A component scripts to be included into your executable script.
Enables several high-level operating system and file system functions.
#>

Write-Information "sys.ps1 script has loaded"

function setWindowsUserPassword {
    param (
        [string] $username,
        [Parameter(mandatory=$true)] [securestring] $password
    )

    if(-Not $username)
    {
        $username = $env:USERNAME
    }
    
    Write-Information "Setting password for Windows user `"$username`""

    [System.Boolean] $savedWhatIf = $WhatIfPreference
    try {
        $WhatIfPreference = $isDebug
        Set-LocalUser -Name $username -Password $password
        Write-Information "Updated password for Windows user `"$username`""
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

function Coalesce {
    param (
        [object] $val,
        [object] $defaultValue = $null
    )

    return $val ? $val : $defaultValue
}

function CoalesceWithEnvVar {
    param (
        [object] $val,
        [string] $envVarName = $null,
        [object] $defaultValue = $null
    )
    
    $v1 = Coalesce $val ([System.Environment]::GetEnvironmentVariable($envVarName))
    return Coalesce $v1 $defaultValue
}

function FalseToNull {
    [CmdletBinding()]
    param(
         [Parameter(ValueFromPipeline)]
         [pscustomobject] $val
    )
    
    return $val ? $val : $null
}

function IsUri($address) {
	return $null -ne ($address -as [System.URI]).AbsoluteURI
}

function IsWebUri($address) {
	$uri = $address -as [System.URI]
	return $null -ne $uri.AbsoluteURI -and $uri.Scheme -match '[http|https]'
}

function GetShortcutPath {
    param(
        [Parameter(mandatory=$true)] [string] $shortcutText,
        [Parameter(mandatory=$true)] [object] $uri
    )

    [string] $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    $shortcutFileExt = (IsWebUri $uri) ? ".url" : ".lnk"
    return Join-Path $desktopPath ($shortcutText + $shortcutFileExt)
}

function CreateDesktopShortcut {
    param(
        [Parameter(mandatory=$true)] [string] $shortcutText,
        [Parameter(mandatory=$true)] [object] $uri
    )

    if(-Not $IsWindows)
    {
        return
    }

    $Shell = New-Object -ComObject ("WScript.Shell")

    [string] $shortcurPath = GetShortcutPath $shortcutText $uri
    
    $ShortCut = $Shell.CreateShortcut($shortcurPath)
    $ShortCut.TargetPath=$uri
    $ShortCut.Save()

    Write-Information "Created `"$shortcurPath`" shortcut pointing to `"$uri`""
}

function DeleteDesktopShortcut {
    param(
        [Parameter(mandatory=$true)] [string] $shortcutText,
        [Parameter(mandatory=$true)] [object] $uri
    )

    if(-Not $IsWindows)
    {
        return
    }

    [string] $shortcurPath = GetShortcutPath $shortcutText $uri
    Remove-Item $shortcurPath -Force

    Write-Information "Removed shortcut `"$shortcurPath`""
}

function Resolve-PathSafe {
    param (
        [Parameter(mandatory=$true)] [string] $path
    )
    
    if(IsUri $path)
    {
        return $path
    }

    [System.Environment]::CurrentDirectory = $pwd
    return [System.IO.Path]::GetFullPath($path)
}
