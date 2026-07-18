@echo off
echo ============================================
echo Streetlore Supabase Seeder
echo ============================================
echo.
echo You need the SERVICE_ROLE key from Supabase:
echo   Project Settings ^> API ^> service_role
echo.
set /p SERVICE_KEY="Paste your service_role key here: "

if "%SERVICE_KEY%"=="" (
    echo No key provided. Exiting.
    exit /b 1
)

echo.
echo Running seed with service_role key...
echo.

cd /d "%~dp0"
dart run tools\seed.dart --dart-define=SUPABASE_SERVICE_ROLE_KEY=%SERVICE_KEY%

echo.
echo Done! Press any key to close.
pause >nul
