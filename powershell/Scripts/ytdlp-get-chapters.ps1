param(
    [string]$url
)
# filtrar:
$url = ($url -replace "&t=\d+s$",'')

if( -not(Get-Command yt-dlp.exe -ErrorAction SilentlyContinue) ) {
    Write-Host " El programa 'yt-dlp.exe' no se encuentra en el PATH... "
    exit 1;
}

$meta = yt-dlp -J $url | Out-String | ConvertFrom-Json
if (-not $meta.chapters) {
    "No chapters found." ; return 
}
$meta.chapters | ForEach-Object {
    "[" + [TimeSpan]::FromSeconds($_.start_time).ToString('hh\:mm\:ss') + "](${url}&t=$($_.start_time)) - " + $_.title
}
