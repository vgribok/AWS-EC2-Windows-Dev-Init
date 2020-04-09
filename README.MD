## Overview

This is a set of PowerShell 7 scripts preparing an AWS EC2 Windows instances (VM) to serve as Workshop/Lab .NET development box, with AWS CLI, AWS Visual Studio Dev Toolbox, AWS user credentials, etc. on the box.

The main functions of the script are:
1. Minimize the amount of boilerplate steps workshop attendees need to take in order to get an EC2 instance configured for .NET development focused workshops, i.e. creating IAM administrator user and configure its AccessKey on the system, so that AWS CLI, PowerShell commands and AWS SDK could run on the system and create AWS resources in the same account where EC2 is running.
2. Enable Workshop authors to take this dev box(es), and parameterize it via EC2 user-data scripts setting environment variables (see below), to pull and build any .NET Core sample app living on GitHub or any other public Git repo.

The script also creates and configures CodeCommit credentials, along with the `aws` Git remote, so that workshop attendee could run "`git push aws`".

These **scripts DO NOT INSTALL SOFTWARE**, like Git or Visual Studio, on the EC2 instance (VM). The AMI image used for creating the VM should have all necessary software installed.

## DISCLAIMER: NO SECURITY AND NO GUARANTEE

__The VM will be absolutely NOT SECURE__ as it will have "Passw0rd" for administrator/root password, and as such an EC2 VM initialized with this script must reside in a locked-down AWS security group and should be shut down right after workshop is completed!

Contributors to this repository will bare no liability or responsibility if a VM initialized with this script causes any harm or damage whatsoever. 

Use at your own risk.

## How to Use

Use these scripts for EC2 initialization and cleanup. Both scripts are idempotent, i.e. one does not have to run "undo" scripts before running "init" scripts, if something didn't work correctly.

### Pre-Requisites

The AMI of the EC2 VM should have following software installed on it:
* [PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows)
* [Git](https://chocolatey.org/packages/git)
* [.NET Core SDK](https://chocolatey.org/packages/dotnetcore-sdk)
* [AWS CLI](https://chocolatey.org/packages/awscli) and [AWS Tools for PowerShell](https://chocolatey.org/packages/AWSTools.Powershell)
* [Visual Studio 2019 Community edition](https://chocolatey.org/packages/visualstudio2019community)
* [AWS Toolkit for Visual Studio](https://aws.amazon.com/visualstudio/)

### EC2 initialization

* Copy [aws-ec2-lab-dev-box-bootstrap.ps1](./src/aws-ec2-lab-dev-box-bootstrap.ps1), [initialize-workshop.bat](./src/initialize-workshop.bat) and [cleanup-after-workshop.bat](/src/cleanup-after-workshop.bat) files to the C:\ of the destination EC2 instance that has IAM Role with the *AdministratorAccess* policy. 

* Run the `C:\initialize-workshop.bat` script before the workshop. It will get latest versions of the rest of the scripts from GitHub. 
* If you maintain an EC2 instance with .NET development tools for workshop/lab purposes, consider running the "C:\initialize-workshop.bat" on system start from Windows Task Scheduler, right after the main AWS EC2 initialization script. Run the script under the "Administrator" user account, if running non-interactively.

Re-Run the "C:\initialize-workshop.bat" script if something didn't work, and create an issue in the [backlog](https://github.com/vgribok/AWS-EC2-Windows-Dev-Init/issues).


### EC2 Cleanup

*Close ALL programs/windows* to ensure files and directories can be deleted, and then run [c:\cleanup-after-workshop.bat](./src/cleanup-after-workshop.bat) after the lab.

The cleanup script will destroy AWS infrastructure created by specified CloudFormation templates, destroy an ECR repo, delete lab user, un-configure AWS credentials on the EC2, and in general will take the system to the state preceding running the initialization script.

# Using EC2 User Data for passing parameters to these scripts baked into an AMI

If your AWS VM (EC2) image, an AMI, has these scripts, their behavior can be driven by supplying a script like this as [EC2 instance user data](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-windows-run-command-new/):
```ps1
<powershell>
[string[][]] $envVars = @(
#@("UNICORN_LAB_INIT_SCRIPT_BRANCH", "development"),
@("UNICORN_LAB_GUIDE_URL", "https://github.com/dotnet/dotnet-docker/blob/master/samples/aspnetapp/README.md"),
@("UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL", "https://github.com/dotnet/dotnet-docker.git"),
@("UNICORN_LAB_SAMPLE_APP_SOLUTION_FILE", "aspnetapp.sln"),
@("UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR", "./samples/aspnetapp/"),
@("UNICORN_LAB_LINUX_DOCKER_START", "true"),
@("UNICORN_LAB_LINUX_DOCKER_AMI", "ami-000000a000aa00aa") # <= use real Linux AMI for the region
)
foreach($pair in $envVars)
{
    if($pair -and $pair[0] -and $pair[0] -ne "ARRAY-STARTER")
    {
        [System.Environment]::SetEnvironmentVariable($pair[0], $pair[1], [System.EnvironmentVariableTarget]::Machine)
    }
}
</powershell>
```
#### Environment Variables as Parameters
All these environment variables are optional. If none are set, the resulting development system will have all the development tool, except Docker for Linux containers, but no sample application and not desktop shortcuts to the lab guide.

* **UNICORN_LAB_INIT_SCRIPT_BRANCH** - Git branch or, better, tag (with "tags/" prefix) name to checkout from this repo when the bootstrapper scripts runs. If not supplied, "master" branch is used, which is not a good idea as branches mutate while tags do not. Using tags is better practice as that creates an immutable envrionment. This variable is used only by the [bootstrapping script](./src/aws-ec2-lab-dev-box-bootstrap.ps1), to enable debugging of these scripts as well as to support creation of immutable environments.

* **UNICORN_LAB_BOOTSTRAP_CDK** - If not blank, will run "`cdk bootstrap`" for current AWS environment, which is a combination of AWS account number and AWS Region.

##### Sample App Parameters

* **UNICORN_LAB_GUIDE_URL** - either an internet URL or a file path to the home page of the workshop instructions/lab guide. If relative file path is used, it should be relative to the sample application location (see below). A desktop shortcut named "Lab Guide" is created pointing to the location provided as a value of this environment variable. If URI is a file path, the shortcut will be created only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was also set.

* **UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL** - sample application Git repository URL. If specified, this git repo will be `git clone` w/o authentication, into a user directory (~/, %USERPROFILE%). If not specified, no sample app will be cloned.

* **UNICORN_LAB_SAMPLE_APP_GIT_BRANCH** - specifies sample application Git branch or tag (with "tags/" prefix). If not set, "master" branch is used. Using tags is a better practice as this creates an immutable environment unaffected by mutating heads of branches. Applies only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was set.

* **UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR** - relative path to a *directory* where sample app's main project or Visual Studio solution file is. If not supplied, main repo directory assumed to be the one. Applies only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was set.

* **UNICORN_LAB_SAMPLE_APP_SOLUTION_FILE** - name of the sample app Visual Studio project or solution file. `dotnet build` will be run for this file. If not specified, `dotnet build` will run against the UNICORN_LAB_SAMPLE_APP_SOLUTION_DIR. The script will not terminate if build has failed. Applies only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was set.

* **UNICORN_LAB_SAMPLE_APP_BUILD_CONFIG** - sample app's build configuration, Like Release or Debug. If not specified *Debug* is used. Applies only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was set.

* **UNICORN_LAB_SAMPLE_APP_CODECOMMIT_REPO_NAME** - configures "aws" git remote for sample app, pointing to an AWS CodeCommit repo of the specified name in the region where the system runs. If not specified, "Unicorn-Store-Sample-Git-Repo" is used. Applies only if UNICORN_LAB_SAMPLE_APP_GIT_REPO_URL was set.

##### Docker Daemon Linux EC2 Parameters

* **UNICORN_LAB_LINUX_DOCKER_START** - if set (not blank), indicates that a satellite Linux EC2 instance hosting remote Docker daemon needs to be started. This enables using Linux Docker containers on Windows, making possible to run commands like `docker build`, `docker images`, `docker ps` to work with Linux containers on the VM.

* **UNICORN_LAB_LINUX_DOCKER_AMI** - a Linux AMI Id with Docker, that will be started as a remote Docker daemon. This Linux instance will be launched in the same VPC and SecurityGroup as where the Windows EC2 instance is. "DOCKER_HOST" header will be set on Windows instance to point to the private IP address of the Linux instance. Applies only when UNICORN_LAB_LINUX_DOCKER_START was set.
  
* **UNICORN_LAB_LINUX_DOCKER_INSTANCE_SIZE** - AWS EC2 instance type for the Docker daemon Linux EC2 instance. If not specified, "[t3a.small](https://ec2instances.info/?filter=t3a.small)" is used. Applies only when UNICORN_LAB_LINUX_DOCKER_START was set.

##### Cleanup/Undo Script Parameters

* **UNICORN_LAB_AWS_RIP_ECR** - an Elastic Container Registry name to be deleted by the undo/clean-up script. Usually used when CDK/CloudFormation is used for a lab, to create an ECR repo. CFN will not destroy an ECR if it's not empty. Does nothing if not specified.

* **UNICORN_LAB_AWS_RIP_CFNS** - a comma-delimited list of CloudFormation stacks to be deleted by the undo/clean-up scripts. Usually used when CDK/CloudFormation is used for a lab. Does nothing if not specified.

## How To Improve These Scripts

### Prerequisites

* Use [VsCode with PowerShell Extension](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-7)
* [Ensure your VsCode PowerShell session runs in PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode?view=powershell-7#choosing-a-version-of-powershell-to-use-with-the-extension) by checking `$PSVersionTable.PSVersion.Major` value, which should be "7".

### How to Develop/Debug These Scripts

It makes most sense to debug these scripts on an EC2 instance. Use VsCode IDE with the PowerShell plugin installed.

General flow is this:
* Open root directory of this project in VsCode
* To initialize everything, run/debug [/src/workshop-prep.ps1](./src/workshop-prep.ps1).
* To cleanup everything, *close ALL programs/windows* and then run/debug [/src/undo-scripts/undo-lab-everything.ps1](./src/undo-scripts/undo-lab-everything.ps1)

When done, please send your pull request.

Thank you!