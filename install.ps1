
Param(
    [string]$link
)

function pause
{
    Write-Host "`n--- Presiona cualquier tecla para continuar ---`n"
    [void][System.Console]::ReadKey($true)
}

function install
{
    Param(
        [string]$dirBase,
        [string]$dirName,
        [string]$target
    )

    $link = Join-Path -Path $dirBase -ChildPath $dirName
    $dirOld = (Get-Location)

    # Corroborar que el directorio base existe:
    if (-not(Test-Path -Path $dirBase)) {
        Write-Host "`n  La dirección [$dirBase], aún NO EXISTE  `n" -BackgroundColor Yellow -ForegroundColor Black 
        New-Item -Type Directory $dirBase -Force | Out-Null
        # Verificar si se creó exitosamente
        if (Test-Path -Path $dirBase) {
            Write-Host ""
            Write-Host "✔ El directorio [$dirBase] fue creado con éxito." -BackgroundColor Green -ForegroundColor Black 
            Write-Host ""
        } else {
            Write-Host ""
            Write-Warning "✘ El directorio NO se creó."
            Write-Host ""
            exit 0
        }
    }


    Set-Location $dirBase

    if (Test-Path -Path $link) {
        $item = Get-Item -Path $link -Force
        if($item.LinkType -eq 'SymbolicLink'){
            Write-Host "✔ La ruta [$link] es un enlace simbólico y apunta a:`n $($item.Target)"
            $opt = Read-Host "`n`nDesea cambiar el enlace simbolico? (Presione `"s`" para continar)"
            if ($opt -eq 's') {
                Write-Host "`n  Cambiando el enlace simbolico...  `n" -BackgroundColor Green -ForegroundColor Black
                Remove-Item $link -Force -Recurse
                New-Item -ItemType SymbolicLink -Path $link -Target $target
            } else {
                Write-Host "`n  El enlace simbolico NO se creará  `n" -BackgroundColor Green -ForegroundColor Black
                return
            }
        }
        else {
            Write-Warning "⚠ La ruta [$link] existe, pero NO es un symlink (LinkType=$($item.LinkType))."
            # Crear un respaldo
            if (Test-Path -Path "$link.original") {
                Write-Warning "  ⚠  Ya existe un respaldo de `"$dirName`".  "
                Remove-Item $link  -Force -Recurse
            } else {
                Write-Warning "  ⚠  Creandose el respaldo de `"$dirName`"...  "
                Rename-Item -Path "$link" -NewName "$link.original" -Force
                #Copy-Item -Path "$link" -Destination "$link.original" -Recurse
                #Remove-Item $link  -Force -Recurse
                #Start-Sleep -Seconds 1
            }
            New-Item -ItemType SymbolicLink -Path $link -Target $target
        }
    }
    else {
        Write-Host "✘ No existe ningún archivo o carpeta llamado '$link'"
        New-Item -ItemType SymbolicLink -Path $link -Target $target
    }


    # Verificar si el enlace simbolico se ha creado exitosamente:
    if (Test-Path -Path $link) {
        Write-Host ""
        Write-Host "  ✔ El directorio [$link] fue creado con éxito.  " -BackgroundColor Green -ForegroundColor Black 
        Write-Host ""
    } else {
        Write-Host ""
        Write-Warning "✘ El directorio [$link] NO se creó."
        Write-Host ""
        exit 0
    }

    Set-Location $dirOld
}

#---------------------------------------------------------------------------
# INICIO
#---------------------------------------------------------------------------


# Eleva a administrador si aún no lo es
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $shell = "powershell.exe"
    if(Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $shell = "pwsh.exe"
    }

    $shellArgList  = @()
    #$shellArgList += "-NoExit"
    $shellArgList += "-WindowStyle"
    $shellArgList += "Maximized"
    $shellArgList += "-ExecutionPolicy"
    $shellArgList += "Bypass"
    $shellArgList += "-NoLogo"
    $shellArgList += "-NoProfile"
    $shellArgList += "-File"
    $shellArgList += $MyInvocation.MyCommand.Path
    #$shellArgList += $commandList

    Start-Process -FilePath $shell -Wait -Verb RunAs -ArgumentList $shellArgList
    
    exit 0

}

# VARIABLES:
$shell = New-Object -ComObject WScript.Shell
$dirNames = @(
        "powershell",
        "vifm",
        "nvim"
    )
$dirBases = @(
        $shell.SpecialFolders("MyDocuments"), # powershell
        $env:APPDATA,                         # vifm
        $env:LOCALAPPDATA                     # nvim
    )
$PSScriptRoot
$targets = @(
        (Join-Path $PSScriptRoot $dirNames[0]), # powershell
        (Join-Path $PSScriptRoot $dirNames[1]), # vifm
        (Join-Path $PSScriptRoot $dirNames[2])  # nvim
    )
$dirNames
$dirBases
$targets
$targets | ForEach-Object{
    if ( -not(Test-Path -Path $_ )) {
        Write-Host "`n  El archivo [" -NoNewline -BackgroundColor Red -ForegroundColor Black
        Write-Host "$_" -NoNewline -BackgroundColor Red -ForegroundColor White
        Write-Host "] NO existe.  `n" -BackgroundColor Red -ForegroundColor Black
        # Pausa antes de salir...
        Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
        [void][System.Console]::ReadKey($true)
        exit 1
    }
}


#Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
#[void][System.Console]::ReadKey($true)
#exit


do {
    Clear-Host
    Write-Host "==== MENÚ PRINCIPAL ===="
    Write-Host "1. Instalar powershell"
    Write-Host "2. Instalar vifm"
    Write-Host "3. Instalar neovim"
    Write-Host "a. Instalar TODO"
    Write-Host "0. Salir"
    Write-Host ""
    $opcion = Read-Host "Elige una opción:"

    switch ($opcion) {
        '1' {
            Clear-Host
            Write-Host
            Write-Host "Instalando PowerShell`n"
            # Iniciar la creación de los enlaces simbolicos:
            install $dirBases[0] $dirNames[0] $targets[0]
            # Pausa antes de salir...
            Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
            [void][System.Console]::ReadKey($true)
        }
        '2' {
            Clear-Host
            Write-Host
            Write-Host "Instalando Vifm`n"
            # Iniciar la creación de los enlaces simbolicos:
            install $dirBases[1] $dirNames[1] $targets[1]
            Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
            [void][System.Console]::ReadKey($true)
        }
        '3' {
            Clear-Host
            Write-Host
            Write-Host "Instalando Neovim`n"
            # Iniciar la creación de los enlaces simbolicos:
            install $dirBases[2] $dirNames[2] $targets[2]
            Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
            [void][System.Console]::ReadKey($true)
        }
        'a' {
            Clear-Host
            Write-Host
            Write-Host "***********************************"
            Write-Host "*        Instalando TODO..        *"
            Write-Host "***********************************"
            Write-Host
            Write-Host "    Instalando PowerShell      `n" -BackgroundColor Yellow -ForegroundColor Black 
            install $dirBases[0] $dirNames[0] $targets[0]
            pause
            Clear-Host
            Write-Host
            Write-Host "***********************************"
            Write-Host "*        Instalando TODO..        *"
            Write-Host "***********************************"
            Write-Host
            Write-Host "      Instalando Vifm      `n" -BackgroundColor Yellow -ForegroundColor Black 
            install $dirBases[1] $dirNames[1] $targets[1]
            pause
            Clear-Host
            Write-Host
            Write-Host "***********************************"
            Write-Host "*        Instalando TODO..        *"
            Write-Host "***********************************"
            Write-Host
            Write-Host "      Instalando Neovim      `n" -BackgroundColor Yellow -ForegroundColor Black 
            install $dirBases[2] $dirNames[2] $targets[2]
            Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
            [void][System.Console]::ReadKey($true)
        }
        '0' {
            Clear-Host
            Write-Host
            Write-Host "Saliendo del menú..."
        }
        default {
            Clear-Host
            Write-Host
            Write-Host "❌ Opción no válida. Intenta de nuevo."
            Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
            [void][System.Console]::ReadKey($true)
        }
    }
} while ($opcion -ne '0')



# Pausa antes de salir...
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)

