$exeFile = "eza.exe"

if( -not(Get-Command $exeFile -ErrorAction SilentlyContinue) ){
    Write-Error "  El programa `"$exeFile`" se encuentra en el sistema...  "
}

$pagAlto = $Host.UI.RawUI.WindowSize.Height
$pagAlto -= 4;

# $comando = "$exeFile -lh --group-dirs=first"  ## lsd.exe
$comando = "$exeFile -lh --group-directories-first --color=always --icons=always --time-style=long-iso"  ## eza.exe

try{
    $linesWithoutPrint = @(Invoke-Expression "$comando")
    $numLinesWithoutPrint = $linesWithoutPrint.Length
    do{
        $indexLastLineToPrint = $pagAlto - 1
        if($numLinesWithoutPrint -lt $pagAlto){ 
            $indexLastLineToPrint = ($numLinesWithoutPrint - 1)
        }
        $linesToPrint = $linesWithoutPrint[0..($indexLastLineToPrint)]
        if($numLinesWithoutPrint -eq ($indexLastLineToPrint+1)){
            $linesWithoutPrint = @()
        } else{
            $linesWithoutPrint = $linesWithoutPrint[($indexLastLineToPrint+1)..($numLinesWithoutPrint-1)]
        }
        $numLinesWithoutPrint = $linesWithoutPrint.Length
        Write-Host
        $linesToPrint | ForEach-Object{Write-Host $_}
        if($numLinesWithoutPrint -ne 0){
            Write-Host
            Write-Host ' -- Presiona Tecla "Espacio" para ir a la siguiente Pag. o "q" para salir --- '
            $key = [System.Console]::ReadKey($true)
            $char = $key.KeyChar;
        }
    }while(($char -ne 'q') -and ( $numLinesWithoutPrint -ne 0) )
    
} catch {
    Write-Host "`n  operación detenida: $_...   `n"
}
