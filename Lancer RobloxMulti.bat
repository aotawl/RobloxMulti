@echo off
cd /d "%~dp0"
if exist "RobloxMulti.exe" (
    start "" "RobloxMulti.exe"
    exit /b
)
if not exist "RobloxMulti.ps1" goto manque
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0RobloxMulti.ps1"
exit /b

:manque
echo [ERREUR] RobloxMulti.ps1 introuvable.
echo Mets "Lancer RobloxMulti.bat" et "RobloxMulti.ps1" dans le MEME dossier.
echo.
pause
