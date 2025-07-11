
#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
$ubicacionesConda = @(
    "conda.exe",
    "$HOME\Anaconda3\Scripts\conda.exe",
    "C:\ProgramData\anaconda3\Scripts\conda.exe"
)

$ubicacionesValidas = @($ubicacionesConda | Where-Object{
        Test-Path $_
    })

if($ubicacionesValidas.Length -gt 0){
    $condaPath = $ubicacionesValidas[0]
    Write-Host "Cargando entorno conda.."
    (& $condaPath "shell.powershell" "hook") | `
            Out-String | `
            Where-Object{$_} | `
            Invoke-Expression
    Write-Host "Entorno conda CARGADO"
}
#endregion


