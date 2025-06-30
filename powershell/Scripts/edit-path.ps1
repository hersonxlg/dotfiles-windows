param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$false)]
    [ValidateSet('User', 'Machine', IgnoreCase)]
    [string]$Scope,
    [switch]$deshacer
)

# VARIABLES:
$path_file_name = ".var_path.txt"
$full_dir_to_file = (Join-Path $HOME $path_file_name)
$temp = (Join-Path $HOME "${path_file_name}.temp")
$backup = (Join-Path $HOME "${path_file_name}.backup")


if ( $Scope -eq "" ) {
    $Scope = "Machine"
}


# ----------------------------------------------------------------------------------------------------
# Recuperar el contenido anterior de la variable PATH
# ----------------------------------------------------------------------------------------------------
if($deshacer){
    Write-Host "Iniciando la recuperación del contenido anterior de PATH" -BackgroundColor Yellow -ForegroundColor Black
    if (Test-Path -Path $backup -PathType Leaf) {
        $dirs_machine = ((Get-Content "$backup") -join ';' )
        $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_machine}', 'Machine')"
        try {
            $pro = Start-Process -wait -Path pwsh `
                -Verb RunAs -PassThru -ErrorAction Stop `
                -ArgumentList @('-noprofile','-nologo',"-command `"${comando}`" ")
        } catch [System.InvalidOperationException] {
            if ($_.Exception.Message -like "*cancelado*") {
                Write-Warning "⚠️ El usuario canceló la elevación (UAC)."
                exit 1;
            } else {
                Write-Error "❌ Start-Process falló: $($_.Exception.Message)"
                exit 1;
            }
        } catch {
            Write-Error "❌ Error inesperado: $($_.GetType().FullName): $($_.Exception.Message)"
            exit 1;
        }
        # Actulizar la variable PATH en la sesión actual de PowerShell:
        $env:path = "${the_rest};${dirs_machine};${dirs_user}"
        Write-Host "`n -- Recuperación exitosa -- `n" -BackgroundColor DarkGreen -ForegroundColor Black
        exit 0;
    } else{
        Write-Host "No se puede recuperar, porque no existe respaldo" -BackgroundColor Red -ForegroundColor Black
        exit 1;
    }
}
# ----------------------------------------------------------------------------------------------------

$editor = "notepad.exe"
if(Get-Command nvim -ErrorAction SilentlyContinue){
    $editor = "nvim"
}

$editCommand = "$editor $full_dir_to_file"
if($editor -eq "notepad.exe"){
    $editCommand = "Start-Process -Wait -WindowStyle Maximized $editor $full_dir_to_file"
}

$path_list = ($env:path -split ';' )
# PATH del sistema:
$dirs_machine = [System.Environment]::GetEnvironmentVariable("path", "Machine")
$dirs_machine_list = ($dirs_machine -split ';')
# PATH del usuario:
$dirs_user = [System.Environment]::GetEnvironmentVariable("path", "User")
$dirs_user_list = ($dirs_user -split ';')
# PATH que combina todo:
$the_rest_list = $($path_list  | Where-Object {
        $_ -notin $dirs_machine_list 
    } | Where-Object {
        $_ -notin $dirs_user_list
    })
$the_rest = ($the_rest_list -join ';')


$comando = ""

if ( $Scope -eq "Machine" ) {
    Write-Output $dirs_machine_list >"$full_dir_to_file"
    Write-Output $dirs_machine_list >"$temp"
    Invoke-Expression $editCommand
    $dirs_machine = ((Get-Content "$full_dir_to_file") -join ';' )
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_machine}', 'Machine')"
} else{
    Write-Output $dirs_user_list >"$full_dir_to_file"
    Write-Output $dirs_user_list >"$temp"
    Invoke-Expression $editCommand
    $dirs_user = ((Get-Content "$full_dir_to_file") -join ';' )
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_user}', 'User')"
}

#***************************************************************************************
#    Abrir una shell con permisos de administrador
#***************************************************************************************

if(Compare-Object -ReferenceObject (Get-Content $full_dir_to_file) -DifferenceObject (Get-Content $temp)){
    # ✅ Los arhivos [$full_dir_to_file] y [$temp] tienen contenido DIFERENTE:
    try {
        $pro = Start-Process -wait -Path pwsh `
            -Verb RunAs -PassThru -ErrorAction Stop `
            -ArgumentList @('-noprofile','-nologo',"-command `"${comando}`" ")
    } catch [System.InvalidOperationException] {
        if ($_.Exception.Message -like "*cancelado*") {
            Write-Warning "⚠️ El usuario canceló la elevación (UAC)."
            Remove-Item "$full_dir_to_file"
            Remove-Item "$temp"
            exit 1;
        } else {
            Write-Error "❌ Start-Process falló: $($_.Exception.Message)"
            Remove-Item "$full_dir_to_file"
            Remove-Item "$temp"
            exit 1;
        }
    } catch {
        Write-Error "❌ Error inesperado: $($_.GetType().FullName): $($_.Exception.Message)"
        Remove-Item "$full_dir_to_file"
        Remove-Item "$temp"
        exit 1;
    }
} else{
    # ✅ Los arhivos [$full_dir_to_file] y [$temp] tienen contenido IGUAL:
    if (Test-Path -Path $temp -PathType Leaf) {
        Remove-Item $temp
    }
    Remove-Item "$full_dir_to_file"
    exit 0;
}

# Actulizar la variable PATH en la sesión actual de PowerShell:
$env:path = "${the_rest};${dirs_machine};${dirs_user}"


if (Test-Path -Path $temp -PathType Leaf) {
    if (Test-Path -Path $backup -PathType Leaf) {
        # ✅ El archivo [$backup] existe:
        if(Compare-Object -ReferenceObject (Get-Content $backup) -DifferenceObject (Get-Content $temp)){
            # ✅ Los arhivos [$backup] y [$temp] tienen contenido DIFERENTE:
            Remove-Item $backup
            Rename-Item -Path $temp -NewName $backup
        }
    } else {
        # ❌ El archivo [$backup] NO existe:
        Rename-Item -Path $temp -NewName $backup
    }
}

if (Test-Path -Path $temp -PathType Leaf) {
    Remove-Item $temp
}
Remove-Item "$full_dir_to_file"
