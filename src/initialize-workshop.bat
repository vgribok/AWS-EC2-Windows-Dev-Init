pwsh.exe -File c:\aws-ec2-lab-dev-box-bootstrap.ps1 -redirectToLog "redirect"
cd "%USERPROFILE%\AWS-EC2-Windows-Dev-Init\src"
copy /Y aws-ec2-lab-dev-box-bootstrap.ps1 aws-workshop-on-user-login.ps1 *.bat c:\*.*
cd /
