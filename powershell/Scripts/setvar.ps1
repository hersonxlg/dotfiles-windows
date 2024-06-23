
# *******************************************************
#             comando "setvar"
# *******************************************************
#
param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
    [string]$variable_name,
    [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$true)]
    [string]$variable_value,
    [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$true)]
    [ValidateSet('User', 'Machine', IgnoreCase)]
    [string]$Scope
    )

if ( $Scope -eq "" ) {
    $Scope = "Machine"
}
if (Test-Path Variable:variable_value) {
    $comando = "[Environment]::SetEnvironmentVariable('${variable_name}', '${variable_value}', '${Scope}')"
    Invoke-Expression "`$Env:${variable_name} = `"${variable_value}`""
}else{
    $comando = "[Environment]::SetEnvironmentVariable('${variable_name}', '', '${Scope}')"
    Invoke-Expression "`$Env:${variable_name} = `"`""
}

Start-Process -wait -verb runas -Path pwsh -ArgumentList '-noprofile','-nologo',"-command `"${comando}`" "
    
