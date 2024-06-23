
param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$false)]
    [ValidateSet('User', 'Machine', IgnoreCase)]
    [string]$Scope
    )


if ( $Scope -eq "" ) {
    $Scope = "Machine"
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
    Write-Output $dirs_machine_list >"_Path_Machine.txt"
    vim "_Path_Machine.txt"
    $dirs_machine = ((Get-Content "_Path_Machine.txt") -join ';' )
    Remove-Item "_Path_Machine.txt"
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_machine}', 'Machine')"
}else{
    Write-Output $dirs_user_list >"_Path_User.txt"
    vim "_Path_User.txt"
    $dirs_user = ((Get-Content "_Path_User.txt") -join ';' )
    Remove-Item "_Path_User.txt"
    $comando = "[Environment]::SetEnvironmentVariable('path', '${dirs_user}', 'User')"
}

Start-Process -wait -verb runas -Path pwsh -ArgumentList '-noprofile','-nologo',"-command `"${comando}`" "
$env:path = "${the_rest};${dirs_machine};${dirs_user}"



