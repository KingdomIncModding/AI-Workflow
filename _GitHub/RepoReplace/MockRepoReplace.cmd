@echo off
setlocal EnableExtensions
if "%~1"=="" (
    echo Drag a mod folder onto MockRepoReplace.cmd to run an OFFLINE test.
    echo The source folder and GitHub will not be modified.
    echo.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MockRepoReplace.ps1" -ModFolder "%~f1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Mock test failed. Exit code: %RESULT%
pause
exit /b %RESULT%
