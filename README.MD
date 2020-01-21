# Overview

A set of PowerShell 6 (Core) scripts preparing an AWS EC2 Windows instances (VM) to serve as Workshop/Lab development box, with AWS CLI, AWS Visual Studio Dev Toolbox, AWS user credentials, etc. on the box.

The main function of the script is to minimize the amount of boilerplate steps workshop attendees need to take in order to get an EC2 instance confgiured for .NET development focused workshops, i.e. *creating IAM administrator user* and configure its AccessKey on the system, so that AWS CLI, PowerShell commands and AWS SDK could run on the system and create AWS resources in the same account where EC2 is running.

The script also creates and configures CodeCommit credentials, along with the `aws` Git remote, so that workshop attendee could run "`git push aws`".

## DISCLAIMER: NO SECURITY AND NO GUARANTEE

__The VM will be absolutely NOT SECURE__ as it will have "Passw0rd" for administrator/root password, and as such an EC2 VM initialized with this script must reside in a locked-down AWS security group and should be shut down right after workshop is completed!

Contributors to thes repository will bare no responsibility if a VM initialized with this script causes any harm or damage whatsoever. 

Use at your own risk.

## How to Use

Use these scripts for EC2 initialization and cleanup. Both scripts are idempotent, i.e. one does not have to run "undo" scripts before running "init" scripts, if something didn't work correctly.

### EC2 initialization

* Copy [aws-ec2-lab-dev-box-bootstrap.ps1](./src/aws-ec2-lab-dev-box-bootstrap.ps1) file to the destination EC2 instance that has Role with the *AdministratorAccess* IAM policy. The IMA needs to have all prerequisite development tools installed: Visual Studio, SQL Server, PowerShell 6, AWS Toolkit, etc.
* If your workshop sample app is on GitHub, you can modify top part (parameters) of the script to point to your sample app.
* Run the script before the workshop. It will get latest versions of the rest of the scripts from GitHub.

Re-Run the scripts if something didn't work, and create an issue in the [backlog](https://github.com/vgribok/AWS-EC2-Windows-Dev-Init/issues).

Use Windows Task Scheduler to run this script on system startup in Windows user context that has administrator privileges. Use Windows Task Scheduler to disable default AWS initializtion script that runs on system startup. This set of scripts invokes AWS script.

Use Windows Task Scheduler to run "`C:\Windows\System32\net.exe user Administrator Passw0rd`" every 5 minute to counteract AWS initialization script and ensure that workshop attendees can RDP into the EC2 lab using well-known password.

### EC2 Cleanup

Run [undo-lab-everything.ps1](./src/undo-scripts/undo-lab-everything.ps1) after the lab. Create a shortcut to the script on the C:\ or in some other well-known and easy to get to location, but not on the desktop so that workshop attendees would not accidentally destroy AWS resources and their dev environment in the middle of the workshop.

The cleanup script will destroy AWS infrastructure created by specified CloudFormation templates, destroy an ECR repo, delete lab user, un-configure AWS credentials on the EC2, and in general will take the system to the state where no AWS CLI, PowreShell or SDK functions can run.

## How To Improve These Scripts

* Use [VsCode with PowerShell Extension](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6)
* [Ensure your VsCode PowerShell session runs in PowerShell 6 (Core)](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-6#choosing-a-version-of-powershell-to-use-with-the-extension) by checking `$PSVersionTable.PSVersion.Major` value, which should be "6".
* Send a PR.