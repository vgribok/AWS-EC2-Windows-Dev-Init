# Overview

A set of PowerShell 6 (Core) scripts preparing an AWS EC2 Windows instances (VM) to serve as Workshop/Lab development box, with AWS CLI, AWS Visual Studio Dev Toolbox, AWS user credentials, etc. on the box.

## DISCLAIMER: NO SECURITY AND NO GUARANTEE

__The VM will be absolutely NOT SECURE__ as it will have "Passw0rd" for administrator/root password, and as such an EC2 VM initialized with this script must reside in a locked-down AWS security group and should be shut down right after workshop is completed!

Contributors to thes repository will bare no responsibility if a VM initialized with this script causes any hard or damage whatsoever. 

Use at your own risk.

## How To Develop

* Use [VsCode with PowerShell Extension](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6)
* [Ensure your VsCode PowerShell session runs in PowerShell 6 (Core)](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6#choosing-a-version-of-powershell-to-use-with-the-extension) by checking `$PSVersionTable.PSVersion.Major` value, which should be "6".