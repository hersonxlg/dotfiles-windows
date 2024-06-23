
# -----------------------------------------------------------------------------
# POWERSHELL 7:
# -----------------------------------------------------------------------------



if ($Host.Version.Major -eq 7){
    start -verb runas powershell -ArgumentList ({sleep 2 ; .\install.ps1 })
    [System.Environment]::Exit(0)
}else{

    $exis_command = (Get-Command pwsh -ErrorAction Ignore)

    if ($exis_command -eq $null){
        Write-Warning "El programa `"Powershell7`" no esta instalado todavía."
    }else{
        Write-Output "El programa `"Powershell7`" esta instalado."
        sleep 2
        # "pwsh.exe" (POWERSHELL 7) está instalado en este sistema.
        $documents_dir = ($PROFILE -replace '\\[^\\]+\\[^\\]+$','')
        $powershell_dir = "${documents_dir}\\powershell"
        if(Test-Path $powershell_dir){ 
            # El directorio $powershell_dir EXISTE.
            if( (Get-Item $powershell_dir).LinkType -eq $null) { 
                # El directorio $powershell_dir NO es un enlace simbolico.
                Write-Output "Se creara el enlace simbolico."
                sleep 2
                if( -not (Test-Path "${powershell_dir}.backout") ){
                    Rename-Item $powershell_dir "${powershell_dir}.backout"
                }
                #New-Item -ItemType SymbolicLink -Path "${documents_dir}" -name "powershell" -Target ".\\powershell"
                $comando = "cd $(pwd) ;New-Item -ItemType SymbolicLink -Path '${documents_dir}' -name 'powershell' -Target '.\\powershell'"
                Write-Output "${comando}"
                Write-Output "`n`n"
                Write-Output "*****************************************************"
                Write-Output "* Se crea el enlace simbolico hacia 'PowerShell'.   *"
                Write-Output "*****************************************************"
                Write-Output " ~\documents\PowerShell                              "
                Write-Output "*****************************************************"
                Write-Output "`n`n"
                sleep 5
                start -verb runas -FilePath powershell -ArgumentList '-noprofile','-noexit','-nologo',"-command ${comando}"
            }else{
                # El directorio $powershell_dir es un enlace simbolico.
                Write-Output "`n`n"
                Write-Output "*****************************************************"
                Write-Output "* Se hace un pull del repositorio 'dotfiles-window' *"
                Write-Output "*****************************************************"
                Write-Output "`n`n"
                sleep 2
                git pull
            }
        }else{
            # El directorio $powershell_dir NO EXISTE.
                $comando = "cd $(pwd) ;New-Item -ItemType SymbolicLink -Path '${documents_dir}' -name 'powershell' -Target '.\\powershell'"
            start -verb runas -FilePath powershell -ArgumentList '-noprofile','-noexit','-nologo',"-command ${comando}"
        }
    }
}


# Abrir de nuevo powershell 7:
wt -d "$(pwd)"

# -----------------------------------------------------------------------------
# neovim:
# -----------------------------------------------------------------------------
