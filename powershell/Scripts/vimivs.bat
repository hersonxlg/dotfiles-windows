@echo off
set "exeFile=vimiv"
where %exeFile% >nul 2>nul
if %errorlevel%==0 (
    powershell -NoProfile -NoLogo -Command "Get-ChildItem $home\Documents\ShareX\Screenshots -File -Recurse  | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object{vimiv $($_.FullName)}"
    REM powershell -NoProfile -NoLogo -Command "echo $home;  Get-ChildItem -Path (""$HOME\Documents\ShareX\Screenshots"") -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object{python -m vimiv $_.FullName}"
) else (
    echo %exeFile% NO está en el PATH
)

