# *******************************************************
#           comando "sudo"
# *******************************************************
param(
[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

[string]$parametros = ""

ForEach ($p in $listaParametros){
    if ($p -match ".*\s.*"){
        $parametros  = "${parametros} '${p}'"
    }else{
        $parametros = "${parametros} ${p}"
    }
}

$parametros = ($parametros -replace '[aáAÁ]','[aáAÁ]')
$parametros = ($parametros -replace '[eéEÉ]','[eéEÉ]')
$parametros = ($parametros -replace '[iíIÍ]','[iíIÍ]')
$parametros = ($parametros -replace '[oóOÓ]','[oóOÓ]')
$parametros = ($parametros -replace '[uúüUÚÜ]','[uúüUÚÜ]')

$parametros = ($parametros -replace '^\s*','')
$parametros = ($parametros -replace '\s*$','')

echo "${parametros}"

