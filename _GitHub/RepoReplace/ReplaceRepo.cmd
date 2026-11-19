@echo off
setlocal EnableExtensions
if "%~1"=="" (
    echo Drag an existing mod folder onto ReplaceRepo.cmd.
    echo.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ReplaceRepo.ps1" -ModFolder "%~f1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Operation failed. Exit code: %RESULT%
pause
exit /b %RESULT%
