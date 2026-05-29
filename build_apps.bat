@echo off
echo ===========================================
echo InventoryPro - Automated Build Separator
echo ===========================================
echo.

set DEFAULT_IP=localhost
echo Note: For Mobile (APK) to sync with the backend running on this PC,
echo please use your local network IP (e.g. 192.168.1.X).
echo For local web/desktop testing only, you can use localhost.
echo.
set /p BACKEND_IP="Enter Backend Server IP [default: %DEFAULT_IP%]: "
if "%BACKEND_IP%"=="" set BACKEND_IP=%DEFAULT_IP%

set API_URL=http://%BACKEND_IP%:8000
set WS_URL=ws://%BACKEND_IP%:8000
echo.
echo Using API URL: %API_URL%
echo Using WS URL:  %WS_URL%
echo.

set /p BUILD_WIN="Compile Windows Desktop App? (y/n) [default: n]: "
if "%BUILD_WIN%"=="" set BUILD_WIN=n

cd inventory_system\flutter_app

echo [1/3] Building Web App...
call flutter build web --dart-define=API_BASE_URL=%API_URL% --dart-define=WS_BASE_URL=%WS_URL%
if %errorlevel% neq 0 (
    echo [!] Failed to build Web App.
    pause
    exit /b %errorlevel%
)

echo [2/3] Building Mobile App (APK)...
call flutter build apk --release --dart-define=API_BASE_URL=%API_URL% --dart-define=WS_BASE_URL=%WS_URL%
if %errorlevel% neq 0 (
    echo [!] Failed to build APK.
    pause
    exit /b %errorlevel%
)

set BUILD_WINDOWS_SUCCESS=0
if /I "%BUILD_WIN%"=="y" (
    echo [3/3] Building Windows Desktop App...
    call flutter build windows --release --dart-define=API_BASE_URL=%API_URL% --dart-define=WS_BASE_URL=%WS_URL%
    if %errorlevel% neq 0 (
        echo [!] Failed to build Windows App. Make sure Visual Studio C++ workloads are installed.
        pause
    ) else (
        set BUILD_WINDOWS_SUCCESS=1
    )
)

echo.
echo Separating outputs into Distribution folder...
cd ..\..
if not exist "Distribution\Web" mkdir "Distribution\Web"
if not exist "Distribution\Mobile" mkdir "Distribution\Mobile"

xcopy /E /I /Y "inventory_system\flutter_app\build\web\*" "Distribution\Web\"
copy /Y "inventory_system\flutter_app\build\app\outputs\flutter-apk\app-release.apk" "Distribution\Mobile\InventoryPro.apk"

if "%BUILD_WINDOWS_SUCCESS%"=="1" (
    if not exist "Distribution\Windows" mkdir "Distribution\Windows"
    xcopy /E /I /Y "inventory_system\flutter_app\build\windows\x64\runner\Release\*" "Distribution\Windows\"
)

echo.
echo ===========================================
echo SUCCESS! Your apps have been compiled and separated.
echo.
echo Web files are in:       Distribution\Web
echo Mobile APK is in:       Distribution\Mobile\InventoryPro.apk
if "%BUILD_WINDOWS_SUCCESS%"=="1" (
    echo Windows Executable in:  Distribution\Windows\inventory_management.exe
)
echo ===========================================
pause
