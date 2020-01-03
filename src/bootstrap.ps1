# Most scripts needed for the task at hand live in GitHub.
# This minimal script, however, can be started on system startup.
param([System.Boolean] $bootstrapDebug = $false)
    Write-Debug "Debugging: $bootstrapDebug"

if ($bootstrapDebug) {
    & ./system-startup.ps1
}else
{
    Set-Location "~"
    git clone https://github.com/vgribok/AWS-EC2-Windows-Dev-Init.git
    & ~/AWS-EC2-Windows-Dev-Init/src/system-startup.ps1
}