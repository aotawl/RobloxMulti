@echo off
cd /d "%~dp0"
if not exist "RobloxMulti.ps1" goto manque
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RobloxMulti.ps1"
exit /b

:manque
echo [ERREUR] RobloxMulti.ps1 introuvable.
echo Mets "Lancer RobloxMulti.bat" et "RobloxMulti.ps1" dans le MEME dossier.
echo.
pause
