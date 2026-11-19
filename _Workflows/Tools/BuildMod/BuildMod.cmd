@echo off
setlocal
if "%~1"=="" (
    echo Drag a mod folder onto this CMD file.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildMod.ps1" -ModFolder "%~1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Build tool stopped with error code %RESULT%.
pause
exit /b %RESULT%
