@echo off
setlocal DisableDelayedExpansion
set "TARGET=%~1"
if not defined TARGET if exist "%~dp0GameViewer.exe" set "TARGET=%~dp0GameViewer.exe"
if not defined TARGET (
  echo IMPORTANT: Choose GameViewer.exe in the VERSION subfolder, NOT the small installation-root launcher.
  echo Example: C:\Program Files\Netease\GameViewer\1.0.0.0\GameViewer.exe
  echo The version directory name may be different on your computer.
  echo Drag the correct executable onto this file, or input its full path.
  set /p "TARGET=GameViewer.exe path: "
)
if not defined TARGET exit /b 2
"%SystemRoot%\System32\cscript.exe" //nologo "%~dp0UU_Win7_MultiVersion.vbs" apply "%TARGET%"
echo.
pause
