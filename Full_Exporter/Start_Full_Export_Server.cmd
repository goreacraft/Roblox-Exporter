@echo off
setlocal
cd /d "%~dp0"

set "EXPORT_TARGET=..\..\Export_FTT"
echo Starting the full script export receiver.
echo Project: %EXPORT_TARGET%
echo Existing src files are replaced only after a complete export arrives.
lune run exportServer_full.luau "%EXPORT_TARGET%"
set "EXPORT_EXIT=%ERRORLEVEL%"
echo.
if not "%EXPORT_EXIT%"=="0" echo Export receiver exited with code %EXPORT_EXIT%.
pause
exit /b %EXPORT_EXIT%
