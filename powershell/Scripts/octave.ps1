$params = ""
if ( $args -notcontains '--gui' )
{
    $params = "--no-gui "
}
foreach ( $param in $args )
{
	if ( $param -match '\s' )
	{
		$param = "`"$param`""
	}
	$params += " $param"
}
# $command = ". `"C:\Program Files\GNU Octave\Octave-8.4.0\octave-launch.exe`" --no-gui --quiet $params"
$command = ". `"octave-launch.exe`" --no-gui --quiet $params"
invoke-expression $command

