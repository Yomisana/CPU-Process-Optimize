@echo off
whoami /groups | find "S-1-5-32-544" > nul
if %errorlevel% neq 0 (
   echo Tips: 本批次檔需要以管理員身份運行。
   pause
   exit /b
)

powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"


powershell -File "%~dp0main.ps1" -ShowProcessInfo
pause