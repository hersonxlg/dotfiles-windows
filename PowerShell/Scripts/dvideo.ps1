
# *******************************************************
#          Comando "dvideo" 
# *******************************************************
param([string]$url)
yt-dlp -f 'bv*[height=1080]+ba' "$url"
