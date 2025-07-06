@echo off

REM ------------------------------
REM      Verificaciones
REM ------------------------------

REM Verificar si el archivo "python.exe" existe
set "exeFile=python"
where %exeFile% >nul 2>nul
if not %errorlevel%==0 (
    echo %exeFile% NO está en el PATH
    exit /b 1
)

REM Verificar que se haya pasado un argumento
if "%~1"=="" (
    %exeFile% -m vimiv
    goto :EOF
)

REM Verificar si el archivo existe
if not exist "%~1" (
    echo El archivo NO existe.
    exit /b 1
)

%exeFile% -m vimiv "%~1"

