@echo off

cd /d "%~dp0"

for /F %%A in ('powershell.exe -Command "if ($(Get-ExecutionPolicy) -eq \"Restricted\") { echo 1 } else {echo 0}" ') do set policy=%%A
if %policy% EQU 1 (
	echo "Your computer is set to NOT allow PowerShell scripts. Please press any key to continue, you will be asked to allow administrative rights once, than a window will open and close instantly, this will allow PowerShell to run freecad_weekly_installer for the future. If you don't want this: close this window and delete freecad_weekly_installer.bat - it will not work without this change."
	pause
	powershell.exe -Command "Start-Process powershell.exe -Verb runAs -ArgumentList \"-Command Set-ExecutionPolicy RemoteSigned -Force;\""
)

powershell.exe -Command "Invoke-WebRequest https://github.com/Tinsus/freecad_weekly_installer/raw/main/freecad_weekly_installer.ps1 -OutFile freecad_weekly_installer.ps1"
powershell.exe -file "freecad_weekly_installer.ps1"
del "freecad_weekly_installer.ps1"
