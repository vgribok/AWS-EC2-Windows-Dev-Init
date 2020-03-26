pwsh.exe -File "%USERPROFILE%\AWS-EC2-Windows-Dev-Init\src\undo-scripts\undo-lab-everything.ps1" -redirectToLog "redirect"
rmdir /S /Q "%USERPROFILE%\AWS-EC2-Windows-Dev-Init"
@echo off
notepad.exe c:\undo-script.log
