
param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$false)]
    [ValidateSet('User', 'Machine', IgnoreCase)]
    [string]$Scope
    )

# VARIABLES:
$path_file_name = "_var_paths.txt"

if ( $Scope -eq "" ) {
    $Scope = "Machine"
}

$editor = "notepad.exe"
if(Get-Command nvim -ErrorAction SilentlyContinue){
	$editor = "nvim"
}

$editCommand = "$editor $path_file_name"
if($editor -eq "notepad.exe"){
    $editCommand = "Start-Process -Wait -WindowStyle Maximized $editor $path_file_name"
}

$path_list = ($env:path -split ';' )
$dirs_machine = [System.Environment]::GetEnvironmentVariable("path", "Machine")
$dirs_machine_list = ($dirs_machine -split ';')
$dirs_user = [System.Environment]::GetEnvironmentVariable("path", "User")
$dirs_user_list = ($dirs_user -split ';')
$the_rest_list = $($path_list  | Where-Object { $_ -notin $dirs_machine_list } | Where-Object { $_ -notin $dirs_user_list})
$the_rest = ($the_rest_list -join ';')


$comando = ""

if ( $Scope -eq "Machine" ) {
    Write-Output $dirs_machine_list >"$path_file_name"
    Invoke-Expression $editCommand
    $dirs_machine = ((Get-Content "$path_file_name") -join ';' )
    Remove-Item "$path_file_name"
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_machine}', 'Machine')"
}else{
    Write-Output $dirs_user_list >"$path_file_name"
    Invoke-Expression $editCommand
    $dirs_user = ((Get-Content "$path_file_name") -join ';' )
    Remove-Item "$path_file_name"
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_user}', 'User')"
}

Start-Process -wait -verb runas -Path pwsh -ArgumentList @('-noprofile','-nologo',"-command `"${comando}`" ")
$env:path = "${the_rest};${dirs_machine};${dirs_user}"



