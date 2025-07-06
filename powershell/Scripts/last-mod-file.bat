@echo off
powershell -NoProfile -Command "Get-ChildItem -Path (Get-Location) -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object{ $_.FullName}"
