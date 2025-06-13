
<#
.SYNOPSIS
  Recarga las variables de entorno de HKLM y HKCU en la sesión actual.
#>

function Refresh-Env {
    [CmdletBinding()]
    param(
      [switch]$Cleanup  # si pasas -Cleanup, hará la limpieza final
    )

    $skip = @(
      'USERPROFILE','HOME','PSMODULEPATH',
      'TEMP','TMP','USERNAME'
    )
    $regPaths = @(
      'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
      'HKCU:\Environment'
    )

    # — 1) Recarga todas las que sí estén en el registro
    foreach ($regPath in $regPaths) {
        $props = Get-ItemProperty -Path $regPath
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.MemberType -eq 'NoteProperty' `
                -and $prop.Value `
                -and ($skip -notcontains $prop.Name)) {

                if ($prop.Name -eq 'Path') {
                    $current = [Environment]::GetEnvironmentVariable('Path','Process')
                    $newItems = $prop.Value -split ';' | Where-Object { $current -notmatch [regex]::Escape($_) }
                    if ($newItems) {
                        $updated = ($current + ';' + ($newItems -join ';')).TrimEnd(';')
                        Set-Item -Path Env:Path -Value $updated
                    }
                }
                else {
                    Set-Item -Path "Env:$($prop.Name)" -Value $prop.Value
                }
            }
        }
    }

    #if ($Cleanup) {
    # — 2) Limpia del proceso las que NO estén ya en el registro
    $procNames = (Get-ChildItem Env:).Name
    $regNames  = @()
    foreach ($regPath in $regPaths) {
        $regNames += (Get-ItemProperty -Path $regPath).PSObject.Properties |
                     Where-Object { $_.MemberType -eq 'NoteProperty' } |
                     Select-Object -ExpandProperty Name
    }
    $regNames = $regNames | Select-Object -Unique
    foreach ($name in $procNames) {
        if (($skip -notcontains $name) -and ($regNames -notcontains $name)) {
            Remove-Item Env:$name -ErrorAction SilentlyContinue
        }
    }
    #}
}

# — Uso básico (resecar y añadir las nuevas)
#Refresh-Env

# — Uso con limpieza (elimina del proceso las ya-borradas del registro)
#Refresh-Env -Cleanup

