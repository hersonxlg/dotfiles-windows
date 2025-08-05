
# *******************************************************
#            Comando "daudio"
# *******************************************************
param(
    [string]$url,
    [string]$name = ""
)
if($name -eq ""){
    yt-dlp -f 'ba' -x --audio-format mp3 "$url"
} else{
    yt-dlp -f 'ba' -x --audio-format mp3 -o "${name}.mp3" "$url"
}
