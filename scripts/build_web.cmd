@echo off
setlocal
if "%API_BASE_URL%"=="" (
  echo Set API_BASE_URL to your deployed Render API URL first.
  echo Example: set API_BASE_URL=https://smart-vendor-api.onrender.com
  exit /b 1
)
cd /d "%~dp0..\frontend"
call flutter pub get
if errorlevel 1 exit /b 1
call flutter analyze
if errorlevel 1 exit /b 1
call flutter build web --release --dart-define=API_BASE_URL=%API_BASE_URL%
if errorlevel 1 exit /b 1
echo Web build created at frontend\build\web
