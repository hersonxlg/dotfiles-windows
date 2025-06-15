
Param (
  [Parameter(Mandatory=$false, HelpMessage="Nombre del Script a buscar.", Position=0)]
  [string] $scriptName = "",
  [Parameter(Mandatory=$false, HelpMessage="Se Muestra el resultado por Pipeline.", Position=1)]
  [switch] $Tuberia = $fase
)

$items = @(Get-ChildItem -Path $PSScriptRoot -File "*.ps1" )

#if($PSBoundParameters.ContainsKey("scriptName")){
if($scriptName){
    $items = @( $items | Where-Object { $_.Name -like "*${scriptName}*" })
}

$size = $items.length

if($size -eq 0){
    Write-Host "`nNo existe ningún Script que contenga `"$scriptName`" en su nombre.`n" -BackgroundColor Red -ForegroundColor Cyan
    exit 0
}

$index = 0..($size-1)


Write-Host ""
if( $Tuberia){
    ($items).Name | ForEach-Object {
        Write-Output "$_"
    }
}else{
    $items = $index | ForEach-Object{"{0,3} --- {1}" -f ($_ + 1),($items[$_].BaseName)}

    $regex="(.*)(${scriptName})(.*)"
    $items | Select-String -Pattern $regex | ForEach-Object {
        $match = $_.Matches[0]
        $antes = $match.Groups[1].Value
        $patron = $match.Groups[2].Value
        $despues = $match.Groups[3].Value

        Write-Host -NoNewline "$antes" -ForegroundColor Gray
        Write-Host -NoNewline "$patron" -ForegroundColor Red
        Write-Host "$despues" -ForegroundColor Gray
    }
}

