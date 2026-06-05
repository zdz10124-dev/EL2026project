@echo off
setlocal
title WhatToEatToday - Backend

cd /d "C:\Projects\2026EL\backend"
if errorlevel 1 (
  echo Failed to enter backend directory:
  echo C:\Projects\2026EL\backend
  echo.
  pause
  exit /b 1
)

echo ========================================
echo Starting FastAPI backend service...
echo URL: http://127.0.0.1:8000
echo Workdir: C:\Projects\2026EL\backend
echo ========================================
echo.
pause

python -m uvicorn main:app --host 0.0.0.0 --port 8000

echo.
echo ========================================
echo Backend process exited. Press any key to close.
echo ========================================
pause
