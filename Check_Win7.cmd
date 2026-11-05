@echo off
setlocal DisableDelayedExpansion
set "TARGET=%~1"
if not defined TARGET if exist "%~dp0GameViewer.exe" set "TARGET=%~dp0GameViewer.exe"
if not defined TARGET (
  echo Drag GameViewer.exe onto this file, or input its full path.
  set /p "TARGET=GameViewer.exe path: "
)
if not defined TARGET exit /b 2
"%SystemRoot%\System32\cscript.exe" //nologo "%~dp0UU_Win7_MultiVersion.vbs" check "%TARGET%"
echo.
pause
