
Param(
    [string]$link
)

# **************************************************************************************
# VARIABLES GLOBALES:
# **************************************************************************************

$shell = New-Object -ComObject WScript.Shell
$oldDir = (Get-Location)
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

function get_status
{
    Param(
        [string]$dirName,
        [string]$dirBase
    )

    [string]$target = (Join-Path $PSScriptRoot $dirName);
    $link = Join-Path -Path $dirBase -ChildPath $dirName

    # Corroborar que el directorio base existe:
    if (-not(Test-Path -Path $dirBase)) {
        Write-Host "`n  La dirección [$dirBase], NO EXISTE  `n" -BackgroundColor Yellow -ForegroundColor Black 
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
                #Remove-Item $link -Force -Recurse
                # Crear un respaldo
                if (Test-Path -Path "$link.original") {
                    Write-Warning "  ⚠  `"$dirName`" incluye respaldo  "
                } else {
                    Write-Warning "  ⚠  `"$dirName`" NO posee respaldo  "
                }
                Write-Host "`n  `"$dirName`" ya está instalado   `n" -BackgroundColor Green -ForegroundColor Black
            } else {
                Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
                return
            }
        }
        else {
            #Write-Warning "⚠ La ruta [$link] existe, pero NO es un symlink (LinkType=$($item.LinkType))."
            #Write-Host "`n  La dirección [$dirBase], NO EXISTE  `n" -BackgroundColor Yellow -ForegroundColor Black 
            Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
            return
        }
    }
    else {
        #Write-Host "`n✘ No existe ningún archivo o carpeta llamado '$link'" -BackgroundColor Yellow -ForegroundColor Black 
        Write-Host "`n  `"$dirName`" no está instalado   `n" -BackgroundColor Magenta -ForegroundColor Black
        return
    }

}

#---------------------------------------------------------------------------
# INICIO
#---------------------------------------------------------------------------


# Eleva a administrador si aún no lo es

$shell = "powershell.exe"
if(Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $shell = "pwsh.exe"
}

##  $shellArgList  = @()
##  #$shellArgList += "-NoExit"
##  $shellArgList += "-WindowStyle"
##  $shellArgList += "Maximized"
##  $shellArgList += "-ExecutionPolicy"
##  $shellArgList += "Bypass"
##  $shellArgList += "-NoLogo"
##  $shellArgList += "-NoProfile"
##  $shellArgList += "-File"
##  $shellArgList += $MyInvocation.MyCommand.Path
##  #$shellArgList += $commandList
##  Start-Process -FilePath $shell -Wait -ArgumentList $shellArgList



#Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
#[void][System.Console]::ReadKey($true)
#exit

Clear-Host
$data | ForEach-Object{
    Write-Host
    Write-Host "****************************************" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host "*      Estado de $('{0,-21}' -f $_[1]) *" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host "****************************************" -BackgroundColor Yellow -ForegroundColor Black 
    Write-Host
    #uninstall  dirName     dirBase
    get_status  $_[1]       $_[2]
}

Set-Location $oldDir

# Pausa antes de salir...
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)

