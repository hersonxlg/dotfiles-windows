param (
    [Parameter(Mandatory = $true)]
    [string]$ProcessName,

    [ValidateSet("Maximize", "Minimize", "Restore")]
    [string]$Action = "Maximize"
)

# Agregar funciones WinAPI para control de ventanas
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32Api {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@ -Language CSharp

# Mapear cada acción a su código numérico de ShowWindow
switch ($Action) {
    "Maximize" { $cmd = 3 }
    "Minimize" { $cmd = 6 }
    "Restore"  { $cmd = 9 }
}

# Obtener procesos que coincidan con el nombre
$processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

# Si no hay procesos, intentar iniciar la aplicación
if (-not $processes) {
    Write-Host "[INFO] Proceso '$ProcessName' no encontrado. Iniciando aplicación..."
    try {
        $processes = Start-Process $ProcessName -PassThru
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Host "[ERROR] No se pudo iniciar la aplicación '$ProcessName'."
        exit 1
    }
}

# Aplicar la acción sobre cada ventana principal
foreach ($proc in $processes) {
    $hWnd = $proc.MainWindowHandle
    if ($hWnd -eq 0) {
        Write-Host "[WARN] El proceso '$($proc.ProcessName)' (PID $($proc.Id)) no tiene ventana principal."
        continue
    }

    # Ejecutar ShowWindow
    [Win32Api]::ShowWindow($hWnd, $cmd) | Out-Null

    # Traer al frente si no es minimizar
    if ($Action -ne "Minimize") {
        [Win32Api]::SetForegroundWindow($hWnd) | Out-Null
    }

    Write-Host "[OK] Acción '$Action' ejecutada en '$($proc.ProcessName)' (PID $($proc.Id))."
}
