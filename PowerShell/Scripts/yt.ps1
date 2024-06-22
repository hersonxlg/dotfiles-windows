
param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

# *******************************************************************
#
#   Lista de datos
#
# *******************************************************************

$sitio_web_donde_buscar="https://www.youtube.com/results?search_query="
$navegador="msedge"

# *******************************************************************

if( (test-path variable:listaParametros) -and ($listaParametros.count -ne 0 ) ) {
    $listaParametros  = ($listaParametros -replace "\s+",'%20')
    $parametros  = ($listaParametros -join '%20')
}else{
    $sitio_web_donde_buscar="https://www.youtube.com"
    $parametros  = ""
}


$comando = "start ${navegador} `"${sitio_web_donde_buscar}${parametros}`""

invoke-expression $comando
