# *******************************************************************
#
#   abrir OBSIDIAN desde CLI
#
# *******************************************************************

param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)



# *******************************************************************


$listaParametros  = ($listaParametros -replace "\s+",' ')
$parametros  = ($listaParametros -join ' ')

$comando = "obs search '/${parametros}'"

invoke-expression $comando
