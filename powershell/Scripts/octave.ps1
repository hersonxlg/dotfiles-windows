# Definir la ruta al ejecutable
$octaveExe = "octave-launch.exe"

# Argumentos base
$baseArgs = "--no-gui --quiet"

# Variable para acumular los argumentos adicionales
$extraArgs = ""

# Recorrer los parámetros pasados al script
for ($i = 0; $i -lt $args.Count; $i++) {
    $currentArg = $args[$i]

    if ($currentArg -eq "--eval" -and ($i + 1) -lt $args.Count) {
        $i++
        $evalCommand = $args[$i]
        # Escapamos comillas dobles internas si existen
        $evalCommand = $evalCommand -replace '"', '\"'
        # Envolvemos el comando eval en comillas dobles de forma literal
        $extraArgs += " --eval `"$evalCommand`""
    } else {
        $extraArgs += " $currentArg"
    }
}

# Ejecutamos mediante el intérprete de comandos para evitar que 
# PowerShell intente desglosar el array de forma incorrecta
$fullCommand = "$baseArgs $extraArgs"
Start-Process -FilePath $octaveExe -ArgumentList $fullCommand -NoNewWindow -Wait
