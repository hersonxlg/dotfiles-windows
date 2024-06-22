
param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

$listaParametros  = ($listaParametros -replace "\s+",'%20')
$parametros  = ($listaParametros -join '%20')

$comando = "start msedge `"www.google.com/search?q=${parametros}`""

write-host $comando

invoke-expression $comando
