
param(
    [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$file
    )

get-content $file | set-clipboard
