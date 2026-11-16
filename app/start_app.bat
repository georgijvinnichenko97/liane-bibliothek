@echo off
rem ================================================================
rem  Lianes Bibliothek, Version 2 - App per Doppelklick starten (Windows)
rem  Vorher einmal in MySQL Workbench ausfuehren:
rem    sql\00_setup_complete.sql
rem ================================================================
cd /d "%~dp0"

rem Anaconda oder Miniconda aktivieren, falls vorhanden
for %%D in ("%USERPROFILE%\anaconda3" "%USERPROFILE%\miniconda3" "%ProgramData%\anaconda3" "%ProgramData%\miniconda3") do (
    if exist "%%~D\Scripts\activate.bat" (
        call "%%~D\Scripts\activate.bat" "%%~D"
        goto :python_suchen
    )
)

:python_suchen
set "PY=python"
python --version >nul 2>nul
if errorlevel 1 set "PY=py"
%PY% --version >nul 2>nul
if errorlevel 1 (
    echo Python wurde nicht gefunden. Bitte Python 3.10 oder neuer installieren.
    pause
    exit /b 1
)

echo Pakete werden geprueft ...
%PY% -m pip install -r requirements.txt --quiet --disable-pip-version-check
echo.
echo Lianes Bibliothek (Version 2) startet. Der Browser oeffnet sich gleich.
echo Adresse: http://localhost:8502
echo Fragt Streamlit nach einer E-Mail-Adresse: einfach Enter druecken.
echo Beenden: dieses Fenster schliessen.
echo.
%PY% -m streamlit run app.py
pause
