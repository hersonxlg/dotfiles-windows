param(
    [string]$fullFileName
)

if($fullFileName -eq '') {
    Write-Error "Debe escribir una dirección hacia un archivo PDF..."
    exit 1;
}
if( -not(Test-Path $fullFileName) ) {
    Write-Error "la dirección no es válida..."
    exit 1;
}

$sourceFile= Get-Item $fullFileName
$fileName = Split-Path -Leaf $fullFileName

if( ($sourceFile.Extension).ToLower() -ne ".pdf") {
    Write-Error "La extensión no es válida (debe ser PDF)..."
    exit 1;
}

$documents = [Environment]::GetFolderPath('MyDocuments')      # Documentos
$dirName = 'Libros (atajos)'
$destinyDir = Join-Path $documents $dirName

if( -not( Test-Path $destinyDir) ) {
    New-Item -ItemType Directory $destinyDir | Out-Null
}

$destinyFile = Join-Path $destinyDir $fileName

if(Test-Path $destinyFile) {
    Write-Error "El archivo que desea agregar a su lista de enlaces simbolicos, Ya existe..."
    exit 1;
}

New-Item -ItemType SymbolicLink -Path $destinyFile -Target $sourceFile

Write-Host $sourceFile
Write-Host $destinyFile

