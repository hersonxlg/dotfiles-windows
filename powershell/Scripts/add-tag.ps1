
# *******************************************************
#             Comando "add-tag"
# *******************************************************

$artista = $($(ls -file).name | Select-String "^.+(?=\s-\s.+\.mp3)").Matches.Value | Select-String "."
$titulo = $($(ls -file).name | Select-String "(?<=^.+\s-\s).+(?=\.mp3)").Matches.Value | Select-String "."
$canciones = $(ls).FullName | Select-String ".+\s-\s.+\.mp3"
$N = $canciones.length 
for ( $i=0; $i -lt $canciones.Length; $i++)
{
	Write-Host "`n`n$($i+1)/$N`t$($titulo[$i]) : $($artista[$i])`n"
	$argTagEditor = "kid3-cli `"$($canciones[$i])`" -c 'set title `"$($titulo[$i])`"' -c 'set artist `"$($artista[$i])`"' "
	Invoke-Expression $argTagEditor
	
}

