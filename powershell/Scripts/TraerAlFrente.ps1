param(
    [Parameter(Mandatory)][string] $ProcessName
)

$ocultarMensajes = $true

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@ -Language CSharp

$SW_RESTORE = 9
$SPI_GETFOREGROUNDLOCKTIMEOUT = 0x2000
$SPI_SETFOREGROUNDLOCKTIMEOUT = 0x2001
$SPIF_SENDCHANGE = 0x2

function Focus-Window
{
    param([IntPtr] $hWnd)

    # Restaurar si está minimizada
    if ([Win32]::IsIconic($hWnd))
    {
        [Win32]::ShowWindow($hWnd, $SW_RESTORE) | Out-Null
    }

    $fg = [Win32]::GetForegroundWindow()
    $ourT = [Win32]::GetCurrentThreadId()
    $fgPID = 0
    $fgT = [Win32]::GetWindowThreadProcessId($fg, [ref] $fgPID)

    $ourPID = 0
    $ourT2 = [Win32]::GetWindowThreadProcessId($hWnd, [ref] $ourPID)

    if ($ourT -ne $fgT)
    {
        [Win32]::AttachThreadInput($ourT, $fgT, $true) | Out-Null
        [Win32]::BringWindowToTop($hWnd) | Out-Null
        [Win32]::SetForegroundWindow($hWnd) | Out-Null
        [Win32]::AttachThreadInput($ourT, $fgT, $false) | Out-Null
    } else
    {
        [Win32]::BringWindowToTop($hWnd) | Out-Null
        [Win32]::SetForegroundWindow($hWnd) | Out-Null
    }

    # Forzar el enfoque aunque Windows lo bloquee)
    $old = [IntPtr]::Zero
    $old = [IntPtr]::Zero
    # Obtener y luego resetear el bloqueo
    $timeout = [IntPtr]::Zero
    [Win32]::SystemParametersInfo($SPI_GETFOREGROUNDLOCKTIMEOUT, 0, $timeout, 0) | Out-Null
    [Win32]::SystemParametersInfo($SPI_SETFOREGROUNDLOCKTIMEOUT, 0, [IntPtr]::Zero, $SPIF_SENDCHANGE) | Out-Null

    [Win32]::BringWindowToTop($hWnd) | Out-Null
    [Win32]::SetForegroundWindow($hWnd) | Out-Null

    # Restaurar el valor original
    [Win32]::SystemParametersInfo($SPI_SETFOREGROUNDLOCKTIMEOUT, 0, $timeout, $SPIF_SENDCHANGE) | Out-Null
}

# Ejecutar
$procs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if (-not $procs)
{
    if( -not $ocultarMensajes)
    {
        Write-Host "[INFO] No se encontró '$ProcessName'. Intentando iniciarlo..."
    }
    exit 0
    ##    try {
    ##        $procs = Start-Process $ProcessName -PassThru
    ##        Start-Sleep -Milliseconds 500
    ##    } catch {
    ##        Write-Error "[ERROR] No se pudo iniciar '$ProcessName'."
    ##        exit 1
    ##    }
}

foreach ($p in $procs)
{
    $h = $p.MainWindowHandle
    if ($h -eq [IntPtr]::Zero)
    {
        if( -not $ocultarMensajes)
        {
            Write-Warning "PID $($p.Id) no tiene ventana visible."
        }
        continue
    }

    Focus-Window -hWnd $h

    if( -not $ocultarMensajes)
    {
        Write-Host "[OK] Ventana de '$($p.ProcessName)' (PID $($p.Id)) traída al frente."
    }
}
