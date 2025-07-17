@echo off
set "prog=ll.ps1"

for %%F in ("%prog%") do (
  if "%%~$PATH:F"=="" (
    echo %prog% no está en el PATH
  ) else (
    powershell -nologo -noprofile -c ll.ps1 %*
  )
)
