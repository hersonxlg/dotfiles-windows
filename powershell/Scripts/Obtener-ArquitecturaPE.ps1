
<#
.SINTESIS
    Obtiene la arquitectura (32-bit, 64-bit, Itanium u otra) de un ejecutable PE de Windows.

.DESCRIPCION
    La función Obtener-ArquitecturaPE analiza el encabezado PE (Portable Executable) del archivo indicado
    y examina el campo Machine del encabezado COFF para identificar la arquitectura de destino.
    Actualmente soporta x86 (32 bits), x64 (64 bits) e Itanium (IA-64). Si el valor no coincide,
    devuelve el código hexadecimal desconocido.

.PARAMETROS
    Ruta
        Ruta al archivo ejecutable (PE) que se desea inspeccionar. Puede ser absoluta o relativa al directorio actual.

.SALIDAS
    Cadena de texto que indica la arquitectura detectada:
    "x86 (32 bits)", "x64 (64 bits)", "Itanium (IA-64)" o "Desconocido (0xXXXX)".

.EJEMPLOS
    PS> .\Obtener-ArquitecturaPE.ps1 -Ruta ".\bin\MiApp.exe"
    x64 (64 bits)

.NOTAS
    Autor: Tu Nombre
    Fecha:  2025-08-05
    Versión: 1.1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'Ruta relativa o absoluta al ejecutable PE.')]
    [ValidateNotNullOrEmpty()]
    [string]$Ruta
)

# Expandir ruta relativa a ruta absoluta basada en el directorio actual
$rutaCompleta = [System.IO.Path]::GetFullPath((Resolve-Path $Ruta))

# Verificar que el archivo existe
if (-not (Test-Path -Path $rutaCompleta -PathType Leaf)) {
    Throw "El archivo especificado no existe: $rutaCompleta"
}

# Abrir el archivo en modo lectura binaria
$flujo = [System.IO.File]::OpenRead($rutaCompleta)
$lector = New-Object System.IO.BinaryReader($flujo)

try {
    # Verificar firma "MZ" (cabecera DOS)
    if ($lector.ReadUInt16() -ne 0x5A4D) {
        Throw "No es un ejecutable PE válido: firma MZ no encontrada."
    }

    # Saltar al offset donde está el puntero al encabezado PE (offset 0x3C)
    $flujo.Position = 0x3C
    $offsetPE = $lector.ReadUInt32()

    # Verificar firma "PE\0\0"
    $flujo.Position = $offsetPE
    if ($lector.ReadUInt32() -ne 0x00004550) {
        Throw "Encabezado PE corrupto: firma PE no encontrada."
    }

    # Leer el campo Machine (2 bytes justo después de la firma PE)
    $maquina = $lector.ReadUInt16()

    # Devolver la arquitectura correspondiente
    switch ($maquina) {
        0x014c {
            return 'x86 (32 bits)' 
        }
        0x8664 {
            return 'x64 (64 bits)' 
        }
        0x0200 {
            return 'Itanium (IA-64)' 
        }
        default {
            return "Desconocido (0x$($maquina.ToString('X4')))" 
        }
    }
} finally {
    # Cerrar lectores y flujos
    $lector.Close()
    $flujo.Close()
}

<## Ejemplo de uso ##>
# Obtener-ArquitecturaPE -Ruta '.\tuPrograma.exe'
# Obtener-ArquitecturaPE -Ruta 'bin\otroPrograma.exe'
