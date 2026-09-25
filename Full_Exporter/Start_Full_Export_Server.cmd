@echo off
setlocal
cd /d "%~dp0"

set "EXPORT_BASE=..\..\Export_FTT\FullScriptExport_Staging"
set "EXPORT_TARGET=%EXPORT_BASE%"
set /a EXPORT_RUN=1

:choose_target
if exist "%EXPORT_TARGET%" (
    set "EXPORT_TARGET=%EXPORT_BASE%_%EXPORT_RUN%"
    set /a EXPORT_RUN+=1
    goto choose_target
)

echo Starting the full script export receiver.
echo Output: %EXPORT_TARGET%
echo Existing export folders are preserved.
lune run exportServer_full.luau "%EXPORT_TARGET%"
set "EXPORT_EXIT=%ERRORLEVEL%"
echo.
if not "%EXPORT_EXIT%"=="0" echo Export receiver exited with code %EXPORT_EXIT%.
pause
exit /b %EXPORT_EXIT%
