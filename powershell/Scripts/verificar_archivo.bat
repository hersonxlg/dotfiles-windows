@echo off
setlocal

REM Verificar que se haya pasado un argumento
if "%~1"=="" (
    echo Uso: %~nx0 ruta\al\archivo
    exit /b 1
)

REM Verificar si el archivo existe
if exist "%~1" (
    echo El archivo existe.
) else (
    echo El archivo NO existe.
)
