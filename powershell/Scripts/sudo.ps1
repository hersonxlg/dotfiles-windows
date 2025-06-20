
# *******************************************************
#           comando "sudo"
# *******************************************************
param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

[string]$comandos = ""

if ($listaParametros -gt 0){
    ForEach ($parametro in $listaParametros){
        if ($parametro -match ".*\s.*"){
            $comandos = "${comandos} '${parametro}'"
        }else{
            $comandos = "${comandos} ${parametro}"
        }
    }
    # ----------------------------------------------------------------------------
    # lista de comandos a ejecutar el la terminal con permisos de administrador:
    # ----------------------------------------------------------------------------
    $lista_de_comandos = "
        ${comandos};
        Write-Host ' ';
        Write-Host 'Presiona Enter para continuar ' -NoNewline -Foreground Blue;
        Write-Host 'o ' -NoNewline;
        Write-Host 'cualquier otra tecla para salir...' -Foreground Red;
        `$key = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        if(`$key.VirtualKeyCode -ne 13) {[System.Environment]::Exit(0)};
    "
    # ----------------------------------------------------------------------------
    Start-Process -verb runas -FilePath pwsh -ArgumentList '-noprofile','-noexit','-nologo',"-command ${lista_de_comandos}"
}else{
    Start-Process -verb runas -FilePath pwsh -ArgumentList '-noprofile','-noexit','-nologo'
}


# start -verb runas -Path pwsh -ArgumentList '-noprofile','-nologo',"-command ${comando} && sleep 2"

