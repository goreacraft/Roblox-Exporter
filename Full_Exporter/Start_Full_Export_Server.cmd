@echo off
cd /d "%~dp0"
echo Starting the full script export receiver.
echo Output: ..\Export_FTT\FullScriptExport_Staging
echo If that target already exists, the exporter will stop safely instead of overwriting it.
lune run exportServer_full.luau ..\..\Export_FTT\FullScriptExport_Staging
pause
