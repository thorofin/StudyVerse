@echo off
title StudyVerse Dev3 Launcher
color 0A

echo.
echo  ================================================
echo   StudyVerse AI Backend Launcher
echo   Developer 3 - ResourceViewModel
echo  ================================================
echo.

:: Save project root (where bat lives)
set ROOT=%~dp0

:: 1. Check Ollama
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Ollama not found. Install from https://ollama.ai
    pause
    exit /b 1
)

:: 2. Start Ollama
echo [1/4] Starting Ollama server...
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
if %errorlevel% neq 0 (
    start /B "" ollama serve
    timeout /t 3 /nobreak >nul
    echo       Ollama started.
) else (
    echo       Ollama already running.
)

:: 3. Check Mistral
echo [2/4] Checking Mistral model...
ollama list 2>nul | findstr /I "mistral" >nul
if %errorlevel% neq 0 (
    echo       Pulling Mistral - first time only ~4GB...
    ollama pull mistral
) else (
    echo       Mistral ready.
)

:: 4. Flask backend
echo [3/4] Starting Flask backend...
cd /d "%ROOT%backend"

if not exist "venv\Scripts\activate.bat" (
    echo       Creating venv...
    python -m venv venv < nul
    call venv\Scripts\activate.bat
    echo       Installing deps...
    pip install -r requirements.txt -q
) else (
    call venv\Scripts\activate.bat
)

start "Flask Backend" cmd /k "cd /d "%ROOT%backend" && call venv\Scripts\activate.bat && python app.py"
timeout /t 3 /nobreak >nul
echo       Flask running on http://localhost:5000

:: 5. Health check
echo [4/4] Waiting for backend...
:WAIT
curl -s http://localhost:5000/api/health >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak >nul
    goto WAIT
)
echo       Backend ready!

:: 6. Flutter - run from project root
echo.
echo  ================================================
echo   Launching Flutter app...
echo  ================================================
echo.
cd /d "%ROOT%"
flutter run

echo.
echo  Done.
pause