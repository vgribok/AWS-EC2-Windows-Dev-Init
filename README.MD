# Overview

A set of PowerShell 6 (Core) scripts preparing an AWS EC2 Windows instances (VM) to serve as Workshop/Lab development box, with AWS CLI, AWS Visual Studio Dev Toolbox, AWS user credentials, etc. on the box.

## How To Develop

* Use [VsCode with PowerShell Extension](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6)
* [Ensure your VsCode PowerShell session runs in PowerShell 6 (Core)](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6#choosing-a-version-of-powershell-to-use-with-the-extension) by checking `$PSVersionTable.PSVersion.Major` value, which should be "6".