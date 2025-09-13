@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pre-push.ps1" %*
exit /b %ERRORLEVEL%
