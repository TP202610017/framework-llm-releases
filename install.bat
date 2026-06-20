@echo off
REM install.bat - one-click installer for isw on Windows.
REM
REM Works from CMD or by double-clicking this file in Explorer. It just runs
REM the PowerShell installer for you (powershell.exe ships with every Windows),
REM so you never have to open PowerShell or type anything.
REM
REM No administrator rights are needed: isw is installed under your user
REM profile (%LOCALAPPDATA%\Programs\isw) and added to your USER PATH only.

setlocal
echo.
echo  Installing isw ...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.ps1 | iex"

if %ERRORLEVEL% neq 0 (
    echo.
    echo  Install failed ^(exit %ERRORLEVEL%^). Check your internet connection and try again.
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo  Done. Open a NEW terminal and run:  isw
echo.
pause
