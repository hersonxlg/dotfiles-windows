
# *******************************************************
#           comando "sudo"
# *******************************************************

Param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$parametros
)

function showList([string[]]$lista){
    $n = $lista.length
    $i = @()
    if($n -ne 0){
        $i = @(0..($n-1))
    }
    $i | ForEach-Object{ Write-Host ('{0,2}:{1}' -f ($_+1),$lista[$_]) -BackgroundColor Green -ForegroundColor Black }
}


# Eleva a administrador si aún no lo es
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $shell = "powershell.exe"
    if(Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $shell = "pwsh.exe"
    }

    #-------------------------------------------------------
    #  POWERSHELL.EXE
    #-------------------------------------------------------
    if($shell -eq "powershell.exe"){

        $commandList  = @($parametros | ForEach-Object{'{0}' -f ($_ -replace '"','"""')})
        if($parametros.length -gt 1){
            $commandList = @($commandList | ForEach-Object{'{0}' -f ($_ -replace '""','""""')})
            $commandList = @($commandList | ForEach-Object{ if($_ -match ' '){'""""{0}""""' -f $_}else{'"{0}"' -f $_} })
        }else{
            #$commandList = @($commandList | ForEach-Object{'{0}' -f ($_ -replace '"','""')})
            $commandList = @($commandList | ForEach-Object{'"" {0} ""' -f $_})
        }

    }

    #-------------------------------------------------------
    #  PWSH.EXE
    #-------------------------------------------------------
    else{
        "pwsh.exe"
        if($parametros.length -gt 1){
            $commandList  = @($parametros | ForEach-Object{'{0}' -f ($_ -replace '"','""""')})
            ##$commandList = @($commandList | ForEach-Object{'{0}' -f ($_ -replace '""','""""')})
            $commandList = @($commandList | ForEach-Object{ if($_ -match ' '){'"""{0}"""' -f $_}else{'"{0}"' -f $_} })
        }else{
            $commandList = @($parametros | ForEach-Object{'{0}' -f ($_ -replace '"','""')})
            $commandList = @($commandList | ForEach-Object{'"{0}"' -f $_})
        }
    }


    $shellArgList  = @()
    $shellArgList += "-WindowStyle"
    $shellArgList += "Maximized"
    $shellArgList += "-ExecutionPolicy"
    $shellArgList += "Bypass"
    $shellArgList += "-NoExit"
    $shellArgList += "-NoLogo"
    $shellArgList += "-NoProfile"
    $shellArgList += "-File"
    #$shellArgList += $PSScriptRoot
    $shellArgList += $MyInvocation.MyCommand.Path
    $shellArgList += $commandList

    Start-Process -FilePath $shell -Wait -Verb RunAs -ArgumentList $shellArgList
    
    exit 0
}


$p = $parametros
$a = $p -join ' '
try{
    iex $a

    Write-Host
    Write-Host 'Presiona Enter para continuar ' -NoNewline -Foreground Blue 
    Write-Host 'o ' -NoNewline
    Write-Host 'cualquier otra tecla para salir...' -Foreground Red
    Write-Host 
    $keyInfo = [System.Console]::ReadKey($true)
    if ($keyInfo.Key -ne 'Enter') {
        if($shell -eq "powershell.exe"){
            exit 0
        }else{
            [System.Environment]::Exit(0)
        }
    }
}catch{
    Write-Host "`n  Ocurrio un ERROR  `n" -BackgroundColor Red -ForegroundColor Black
    Sleep 4
    [System.Environment]::Exit(1)
}

