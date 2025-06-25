
Param(
    [string]$link
)

# **************************************************************************************
# VARIABLES GLOBALES:
# **************************************************************************************

$shell = New-Object -ComObject WScript.Shell

$data = @(
    #@(ejecutables,  dirNames   ,     dirBases                       )
    @( "pwsh.exe" , "powershell",$shell.SpecialFolders("MyDocuments")), # pwsh
    @( "vifm.exe" , "vifm"      ,$env:APPDATA                        ), # vifm
    @( "nvim.exe" , "nvim"      ,$env:LOCALAPPDATA                   )  # nvim
)


# **************************************************************************************
# FUNCIONES:
# **************************************************************************************
Function pause
{
    Write-Host "`n--- Presiona cualquier tecla para continuar ---`n"
    [void][System.Console]::ReadKey($true)
}


Function Remove-Dir([string]$folder)
{
    if (Test-Path $folder) {
        try {
            Remove-Item $folder -Recurse -Force
            Write-Host "✔ Carpeta eliminada: $folder"
        } catch {
            Write-Error "❌ Error al eliminar carpeta: $_"
        }
    } else {
        Write-Host "ℹ No existe la carpeta: $folder"
    }
}

Function install
{
    Param(
        [string]$exeName,
        [string]$dirName,
        [string]$dirBase
    )

    [string]$target = (Join-Path $PSScriptRoot $dirName);
    $link = Join-Path -Path $dirBase -ChildPath $dirName;
    $dirOld = (Get-Location);

    # Corroborar que el archivo ejecutable existe:
    if( -not(Get-Command $exeName -ErrorAction SilentlyContinue) ){
        Write-Host "`n  El ejecutable `"$exeName`", NO EXISTE  `n" -BackgroundColor Red -ForegroundColor Black ;
        return;
    }

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
                #Remove-Item $link -Force -Recurse
                Remove-Dir($link)
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
                pause
                Remove-Dir($link)
                #Remove-Item -Path $link  -Force -Recurse
                Write-Host "`n  `"$link`" se ha removido  `n" -ForegroundColor Red
                pause
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

    # Validar si se abre la shell con permisos de administrador:
    try {
        $proc = Start-Process -FilePath $shell `
                -Wait -Verb RunAs -PassThru -ErrorAction Stop `
                -ArgumentList $shellArgList
    }
    catch [System.InvalidOperationException] {
        if ($_.Exception.Message -like "*cancelado*") {
            Write-Warning "⚠️ El usuario canceló la elevación (UAC)."
        } else {
            Write-Error "❌ Start-Process falló: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Error "❌ Error inesperado: $($_.GetType().FullName): $($_.Exception.Message)"
    }

    exit 0

}

# **************************************************************************************
# validaciones:
# **************************************************************************************

$data | ForEach-Object{
    $target =  (Join-Path $PSScriptRoot $_[1]);
    if ( -not(Test-Path -Path $target)) {
        Write-Host "`n  El archivo [" -NoNewline -BackgroundColor Red -ForegroundColor Black
        Write-Host "$target" -NoNewline -BackgroundColor Red -ForegroundColor White
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


# **************************************************************************************
# MENU:
# **************************************************************************************
do {
    Clear-Host
    Write-Host "==== MENÚ PRINCIPAL ===="
    $index = 0
    $data | ForEach-Object{
            Write-Host "$($index+2). Instalar $($_[1])"
            $index++;
        }
    Write-Host
    Write-Host "1. Instalar TODO"
    Write-Host "0. Salir"
    Write-Host
    [int]$opcion = Read-Host "Elige una opción:"

    if( ($opcion -ge 2) -and ($opcion -le ($data.length + 1)) ){
        [int]$i = ($opcion - 2)
        Clear-Host
        Write-Host
        Write-Host "******************************************" -BackgroundColor Yellow -ForegroundColor Black 
        Write-Host "*  Instalando $('{0,-27}' -f ($data[$i][1]) )*" -BackgroundColor Yellow -ForegroundColor Black 
        Write-Host "******************************************" -BackgroundColor Yellow -ForegroundColor Black 
        Write-Host
        #install exeName        dirName         dirBase
        install  $data[$i][0]   $data[$i][1]    $data[$i][2];
        pause
    }
    elseif($opcion -eq 1){
        $data | ForEach-Object{
            Clear-Host
            Write-Host
            Write-Host "******************************************" -BackgroundColor Yellow -ForegroundColor Black 
            Write-Host "*  Instalando $('{0,-27}' -f $_[1])*" -BackgroundColor Yellow -ForegroundColor Black 
            Write-Host "******************************************" -BackgroundColor Yellow -ForegroundColor Black 
            Write-Host
            #install exeName  dirName  dirBase
            install  $_[0]    $_[1]    $_[2]
            pause
        }
    }
    elseif($opcion -eq 0){
        Clear-Host
        Write-Host
        Write-Host "Saliendo del menú..."
        Write-Host
    }
    else{
        Clear-Host
        Write-Host
        Write-Host "❌ Opción no válida. Intenta de nuevo."
        Write-Host "`n--- Presiona cualquier tecla para regresar al menu ---`n"
        [void][System.Console]::ReadKey($true)
    }
} while ($opcion -ne '0')


# Pausa antes de salir...
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)

