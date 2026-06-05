@echo off
setlocal
title WhatToEatToday - Tunnel

if not exist "C:\cloudflared\cloudflared.exe" (
  echo cloudflared.exe was not found:
  echo C:\cloudflared\cloudflared.exe
  echo.
  pause
  exit /b 1
)

echo ========================================
echo Starting Cloudflare Tunnel...
echo Public URL: https://api.whateattoday.xyz
echo Tunnel: eat-tunnel
echo ========================================
echo.
pause

"C:\cloudflared\cloudflared.exe" tunnel run eat-tunnel

echo.
echo ========================================
echo Tunnel process exited. Press any key to close.
echo ========================================
pause
