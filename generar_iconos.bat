@echo off
REM Script para generar iconos SkyPulse (Windows)

echo ========================================
echo   Generando iconos SkyPulse
echo ========================================
echo.

REM Verificar ImageMagick instalado
where convert >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ImageMagick no esta instalado
    echo.
    echo Instalacion:
    echo   choco install imagemagick
    echo.
    echo O descargar de: https://imagemagick.org/script/download.php
    pause
    exit /b 1
)

echo [OK] ImageMagick encontrado
echo.

REM Crear carpetas
echo Creando estructura de carpetas...
mkdir assets 2>nul
mkdir android_icons\mipmap-mdpi 2>nul
mkdir android_icons\mipmap-hdpi 2>nul
mkdir android_icons\mipmap-xhdpi 2>nul
mkdir android_icons\mipmap-xxhdpi 2>nul
mkdir android_icons\mipmap-xxxhdpi 2>nul

if not exist "assets\logo.svg" (
    echo [ERROR] No se encuentra assets\logo.svg
    echo Copia el archivo logo.svg a la carpeta assets\
    pause
    exit /b 1
)

echo.
echo Generando PNG desde SVG...

REM Logo principal
convert -background none -resize 512x512 assets\logo.svg assets\logo.png
echo [OK] assets\logo.png (512x512)

REM Android launcher icons
echo.
echo Generando iconos Android...
convert -background none -resize 48x48 assets\logo.svg android_icons\mipmap-mdpi\ic_launcher.png
echo [OK] mipmap-mdpi (48x48)

convert -background none -resize 72x72 assets\logo.svg android_icons\mipmap-hdpi\ic_launcher.png
echo [OK] mipmap-hdpi (72x72)

convert -background none -resize 96x96 assets\logo.svg android_icons\mipmap-xhdpi\ic_launcher.png
echo [OK] mipmap-xhdpi (96x96)

convert -background none -resize 144x144 assets\logo.svg android_icons\mipmap-xxhdpi\ic_launcher.png
echo [OK] mipmap-xxhdpi (144x144)

convert -background none -resize 192x192 assets\logo.svg android_icons\mipmap-xxxhdpi\ic_launcher.png
echo [OK] mipmap-xxxhdpi (192x192)

REM Adaptive icons
echo.
echo Generando adaptive icons...
convert -background none -resize 108x108 assets\logo.svg android_icons\mipmap-mdpi\ic_launcher_foreground.png
convert -background none -resize 162x162 assets\logo.svg android_icons\mipmap-hdpi\ic_launcher_foreground.png
convert -background none -resize 216x216 assets\logo.svg android_icons\mipmap-xhdpi\ic_launcher_foreground.png
convert -background none -resize 324x324 assets\logo.svg android_icons\mipmap-xxhdpi\ic_launcher_foreground.png
convert -background none -resize 432x432 assets\logo.svg android_icons\mipmap-xxxhdpi\ic_launcher_foreground.png
echo [OK] Adaptive icons generados

echo.
echo ========================================
echo   Iconos generados exitosamente!
echo ========================================
echo.
echo Proximos pasos:
echo   1. Copiar android_icons\* a:
echo      android\app\src\main\res\
echo.
echo   2. Copiar assets\logo.png a tu proyecto
echo.
pause
