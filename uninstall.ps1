
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
function pause
{
    Write-Host "`n--- Presiona cualquier tecla para continuar ---`n"
    [void][System.Console]::ReadKey($true)
}

function uninstall
{
    Param(
        [string]$dirName,
        [string]$dirBase
    )

    [string]$target = (Join-Path $PSScriptRoot $dirName);
    $link = Join-Path -Path $dirBase -ChildPath $dirName
    $dirOld = (Get-Location)

    # Corroborar que el directorio base existe:
    if (-not(Test-Path -Path $dirBase)) {
        Write-Host "`n  La dirección [$dirBase], NO EXISTE  `n" -BackgroundColor Magenta -ForegroundColor Black 
        Start-Sleep -Seconds 2
        Write-Host "`n  NO SE PUEDE DESINSTALAR `"$dirName`"  `n" -BackgroundColor Red -ForegroundColor Black 
        return
    }

    Set-Location $dirBase

    if (Test-Path -Path $link) {
        $item = Get-Item -Path $link -Force
        if($item.LinkType -eq 'SymbolicLink'){
            if ($item.Target -eq $target) {
                ##echo "enlace: [$($item.Target)]"
                ##echo "repo  : [$target]"
                ##pause
                Remove-Item $link -Force -Recurse
                # Crear un respaldo
                if (Test-Path -Path "$link.original") {
                    Copy-Item -Path "$link.original" -Destination "$link" -Recurse
                } else {
                    Write-Warning "  ⚠  `"$dirName`" NO posee respaldo  "
                }
                Write-Host "`n  Desintalación de `"$dirName`" fue exitosa  `n" -BackgroundColor Green -ForegroundColor Black
            } else {
                Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
                return
            }
        }
        else {
            #Write-Warning "⚠ La ruta [$link] existe, pero NO es un symlink (LinkType=$($item.LinkType))."
            #Write-Host "`n  La dirección [$dirBase], NO EXISTE  `n" -BackgroundColor Magenta -ForegroundColor Black 
            Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
            return
        }
    }
    else {
        #Write-Host "`n✘ No existe ningún archivo o carpeta llamado '$link'" -BackgroundColor Magenta -ForegroundColor Black 
        Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
        return
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


Clear-Host
$data | ForEach-Object{
    Write-Host
    Write-Host "****************************************" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host "*   Desinstalando $('{0,-21}' -f $_[1])*" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host "****************************************" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host
    #uninstall  dirName     dirBase
    uninstall   $_[1]       $_[2]
}


# Pausa antes de salir...
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)

