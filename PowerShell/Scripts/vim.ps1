
param(
[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromRemainingArguments)]
[string[]]$listaParametros)

[string]$parametros = ""


ForEach ($p in $listaParametros){
    $parametros  = "${parametros} `"${p}`""
}


$comando = "nvim ${parametros}"

invoke-expression $comando

Write-Host -NoNewLine "`e[5 q"
