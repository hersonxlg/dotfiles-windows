
# *******************************************************
#            Comando "daudio"
# *******************************************************
param([string]$url)
yt-dlp -f 'ba' -x --audio-format mp3 "$url"
