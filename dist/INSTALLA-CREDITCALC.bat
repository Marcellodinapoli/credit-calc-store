@echo off
chcp 65001 >nul
setlocal
set "DIR=%~dp0"

echo.
echo  CreditCalc per Windows - installazione
echo  =====================================
echo.

for %%F in ("%DIR%CreditCalc-*-Setup.exe") do (
    echo Avvio installer...
    echo   %%~nxF
    echo.
    start "" "%%F"
    exit /b 0
)

for /d %%D in ("%DIR%CreditCalc-*-win64") do (
    if exist "%%D\CreditCalc.exe" (
        echo Avvio versione portable...
        echo   %%D\CreditCalc.exe
        start "" "%%D\CreditCalc.exe"
        exit /b 0
    )
)

for %%Z in ("%DIR%CreditCalc-*-win64.zip") do (
    echo File trovato: %%~nxZ
    echo Estrai lo ZIP e avvia CreditCalc.exe nella cartella estratta.
    explorer /select,"%%Z"
    exit /b 0
)

echo Nessun file di installazione in questa cartella.
echo Esegui prima: scripts\scarica_installer_pc.ps1
pause
exit /b 1
