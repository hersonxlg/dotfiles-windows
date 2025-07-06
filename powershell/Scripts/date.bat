@echo off
for /f "skip=1 tokens=1-6" %%A in (
  'wmic Path Win32_LocalTime Get Day^,Month^,Year /Format:table'
) do (
  if not "%%B"=="" (
    set "Day=00%%A"
    set "Month=00%%B"
    set "Year=%%C"
  )
)
set "Day=%Day:~-2%"
set "Month=%Month:~-2%"

set "date=Día=%Day% Mes=%Month% Año=%Year%"

echo %date%
