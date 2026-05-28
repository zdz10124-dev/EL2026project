@echo off
chcp 65001 >nul
title CyberCoach

echo ============================================
echo  赛博教练 (CyberCoach) - 一键启动
echo ============================================
echo.

REM 清理残留进程
echo [清理] 检查残留进程...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3001 " ^| findstr LISTEN') do (
    echo   关闭后端进程 PID %%a
    taskkill /F /PID %%a >nul 2>&1
)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5173 " ^| findstr LISTEN') do (
    echo   关闭前端进程(5173) PID %%a
    taskkill /F /PID %%a >nul 2>&1
)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5174 " ^| findstr LISTEN') do (
    echo   关闭前端进程(5174) PID %%a
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 1 /nobreak >nul
echo.

REM 检查依赖
if not exist "cybercoach-server\node_modules" (
    echo [1/3] 安装后端依赖...
    cd cybercoach-server
    call npm install
    cd ..
) else (
    echo [1/3] 后端依赖已安装
)

if not exist "cybercoach-web\node_modules" (
    echo [2/3] 安装前端依赖...
    cd cybercoach-web
    call npm install
    cd ..
) else (
    echo [2/3] 前端依赖已安装
)

echo [3/3] 启动服务...
echo.
echo  后端: http://localhost:3001
echo  前端: http://localhost:5173
echo.
echo  关闭此窗口将停止所有服务
echo ============================================
echo.

REM 启动后端（后台运行）
start "CyberCoach-Server" cmd /c "cd /d %~dp0cybercoach-server && npx tsx src/index.ts"

REM 等待后端启动
timeout /t 2 /nobreak >nul

REM 启动前端（前台）
cd /d %~dp0cybercoach-web
npx vite
cd /d %~dp0

echo 正在关闭后端服务...
taskkill /FI "WINDOWTITLE eq CyberCoach-Server" /F >nul 2>&1
echo 已停止所有服务。
pause
