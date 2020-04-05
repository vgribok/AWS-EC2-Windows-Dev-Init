<#
A component scripts to be included into your executable script.
Enables several high-level operating system and file system functions.
#>

Write-Information "sys.ps1 script has loaded"

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

function OverrideWithEnvVar {
    param (
        [string] $val,
        [string] $envVar
    )
    
    if($envVar)
    {
        [string] $varVal = [System.Environment]::GetEnvironmentVariable($envVar)
        if($varVal)
        {
            $val = $varVal
        }
    }

    return $val
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
        [Parameter(mandatory=$true)] [string] $shortcutName,
        [string] $uriOrExt = $null
    )

    if($uriOrExt)
    {
        [string] $uriOrExtLower = $uriOrExt.ToLowerInvariant()

        if($uriOrExtLower.EndsWith(".lnk") -or $uriOrExtLower.EndsWith(".url"))
        {
            $shortcutFileExt = $uriOrExt
        }else
        {
            $shortcutFileExt = (IsWebUri $uriOrExt) ? ".url" : ".lnk"
        }
    }else {
        $shortcutFileExt = ""
    }

    [string] $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    return Join-Path $desktopPath ($shortcutName + $shortcutFileExt)
}

function Resolve-PathSafe {
    param (
        [Parameter(mandatory=$true)] [string] $path
    )

    return (IsUri $path) ? $path : $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
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
    $ShortCut.TargetPath = Resolve-PathSafe $uri
    $ShortCut.Save()

    Write-Information "Created `"$shortcurPath`" shortcut pointing to `"$($ShortCut.TargetPath)`""
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
