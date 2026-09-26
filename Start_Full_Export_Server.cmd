@echo off
setlocal
cd /d "%~dp0"

set "EXPORT_TARGET=..\Export_FTT"
set "EXPORT_DEBUG="
if /I "%~1"=="-debug" set "EXPORT_DEBUG=-debug"
if not "%~1"=="" if not defined EXPORT_DEBUG (
    echo Unknown option: %~1
    echo Usage: Start_Full_Export_Server.cmd [-debug]
    pause
    exit /b 2
)
echo Starting the full script export receiver.
echo Project: %EXPORT_TARGET%
if defined EXPORT_DEBUG echo Debug manifest enabled.
echo Existing src files are replaced only after a complete export arrives.
lune run exportServer_full.luau "%EXPORT_TARGET%" %EXPORT_DEBUG%
set "EXPORT_EXIT=%ERRORLEVEL%"
echo.
if not "%EXPORT_EXIT%"=="0" echo Export receiver exited with code %EXPORT_EXIT%.
pause
exit /b %EXPORT_EXIT%
