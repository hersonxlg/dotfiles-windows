<#
.SYNOPSIS
Detecta y normaliza nombres de archivos y carpetas que usen caracteres Unicode en forma NFD.

.DESCRIPTION
Este script escanea los archivos y subdirectorios de un directorio en Windows y detecta aquellos cuyo nombre contiene caracteres en forma de descomposición Unicode (NFD), como letras con acentos combinados.

Puede normalizar esos nombres a la forma compuesta estándar (NFC), preguntando al usuario o haciéndolo automáticamente. También puede guardar un registro de los cambios.

.PARAMETER Path
Ruta del directorio a escanear. Si no se proporciona, se solicita interactivamente.

.PARAMETER Recurse
Indica que se deben procesar también los subdirectorios recursivamente.

.PARAMETER Auto
Realiza el renombramiento automáticamente sin preguntar.

.PARAMETER Log
Guarda un registro de los cambios en un archivo `normaliza-nombres.log` en el directorio especificado.

.EXAMPLE
.\normaliza-nombres.ps1 -Path "C:\Mis Archivos"

Escanea solo el primer nivel del directorio y pregunta antes de renombrar.

.EXAMPLE
.\normaliza-nombres.ps1 -Path "C:\Mis Archivos" -Recurse -Auto -Log

Escanea recursivamente, renombra sin preguntar y guarda un log.

.NOTES
Autor: ChatGPT para Xavier Gómez
Requiere: PowerShell 5 o superior

#>
param (
    [string]$Path,
    [switch]$Recurse,
    [switch]$Auto,
    [switch]$Log
)

# Solicitar la ruta si no se pasó por parámetro
if (-not $Path) {
    $Path = Read-Host "Introduce la ruta del directorio a escanear"
}

# Validar existencia
if (-not (Test-Path $Path)) {
    Write-Host "❌ La ruta '$Path' no existe."
    exit
}

# Inicializar normalización NFC
$normalizationForm = [Text.NormalizationForm]::FormC

# Configurar logging
if ($Log) {
    $logFile = Join-Path -Path $Path -ChildPath "normaliza-nombres.log"
    "Log iniciado: $(Get-Date)" | Out-File -FilePath $logFile -Encoding utf8
}

# Mostrar modo actual
Write-Host "`n📁 Ruta base: $Path"
Write-Host "🔍 Modo recursivo: $Recurse"
Write-Host "⚙️  Modo automático: $Auto"
Write-Host "📝 Guardar log: $Log`n"

# Obtener elementos
$items = Get-ChildItem -Path $Path -Force -File -Directory -Recurse:$Recurse

foreach ($item in $items) {
    $nameOriginal = $item.Name
    $nameNFC = $nameOriginal.Normalize($normalizationForm)

    # Comparación binaria (ordinal)
    if ([String]::Compare($nameOriginal, $nameNFC, [StringComparison]::Ordinal) -ne 0) {
        $fullOriginal = $item.FullName
        $newFullPath = Join-Path -Path $item.DirectoryName -ChildPath $nameNFC

        Write-Host "🔍 NFD detectado:"
        Write-Host "  ➤ Actual:   $nameOriginal"
        Write-Host "  ➤ Sugerido: $nameNFC"

        $renombrar = $Auto

        if (-not $Auto) {
            $respuesta = Read-Host "¿Deseas renombrarlo? (s/n)"
            $renombrar = ($respuesta -ieq "s")
        }

        if ($renombrar) {
            try {
                Rename-Item -LiteralPath $fullOriginal -NewName $nameNFC
                Write-Host "✅ Renombrado a: $nameNFC`n"

                if ($Log) {
                    "Renombrado: '$nameOriginal' → '$nameNFC'" | Out-File -Append -FilePath $logFile -Encoding utf8
                }
            }
            catch {
                Write-Host "❌ Error al renombrar: $_`n"
                if ($Log) {
                    "Error al renombrar '$nameOriginal': $_" | Out-File -Append -FilePath $logFile -Encoding utf8
                }
            }
        }
        else {
            Write-Host "⏭️  Saltado: $nameOriginal`n"
        }
    }
}
