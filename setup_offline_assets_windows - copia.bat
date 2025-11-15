@echo off
REM === Siempre ejecutar desde la RAIZ del proyecto ===
cd /d "%~dp0"

echo === Paso 1: Crear carpetas de assets ===
mkdir assets 2>nul
mkdir assets\offline 2>nul
mkdir assets\aves 2>nul

echo === Paso 2: Verificar archivos ===
if not exist assets\offline\offline_db.json (
  echo ERROR: No se encuentra assets\offline\offline_db.json
  echo Si no lo tienes, genera uno con:
  echo   python tools\fetch_media_v7_1.py --excel Aves_Murocomba_Completo_21-09-25.xlsx --out-db assets\offline\offline_db.json
  pause
  exit /b 1
)
if not exist tools\fetch_media_v7_1.py (
  echo ERROR: No se encuentra tools\fetch_media_v7_1.py
  pause
  exit /b 1
)

echo === Paso 3: Crear venv e instalar dependencias ===
python --version
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Python no encontrado. Instala Python 3.10+ y agrega al PATH.
  pause
  exit /b 1
)

if not exist .venv (
  python -m venv .venv
)
call .venv\Scripts\activate

python -m pip install --upgrade pip
pip install requests pandas openpyxl

echo === Paso 4: Descargar IMAGEN + ESPECTROGRAMA por especie ===
python tools\fetch_media_v7_1.py ^
  --db assets\offline\offline_db.json ^
  --out-db assets\offline\offline_db.json ^
  --base-dir assets\aves ^
  --delay 2

echo === Paso 5: Recuerda actualizar pubspec.yaml ===
echo   flutter:
echo     assets:
echo       - assets/offline/offline_db.json
echo       - assets/aves/
echo Luego ejecuta: flutter pub get

echo === FIN ===
pause
