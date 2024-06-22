
# *******************************************************
#           comando "sudo"
# *******************************************************
param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

[string]$comando = ""

if ($listaParametros -gt 0){
    ForEach ($parametro in $listaParametros){
        if ($parametro -match ".*\s.*"){
            $comando = "${comando} '${parametro}'"
        }else{
            $comando = "${comando} ${parametro}"
        }
    }
    start -verb runas -Path pwsh -ArgumentList '-noprofile','-noexit','-nologo',"-command ${comando}"
}else{
    start -verb runas -Path pwsh -ArgumentList '-noprofile','-noexit','-nologo'
}


# start -verb runas -Path pwsh -ArgumentList '-noprofile','-nologo',"-command ${comando} && sleep 2"

