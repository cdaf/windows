Write-Host
Write-Host "[setenv.ps1] ---------- start ----------"
$variable = $args[0]
$value    = $args[1]
$target   = $args[2]

# vagrant file share is dependant on provider, for VirtualBox, pass as C:\vagrant\.provision
if ($variable) {
    Write-Host "[setenv.ps1] variable : $variable"
} else {
    Write-Host "[setenv.ps1] variable required, exiting!"
    exit 100
}

if ($value) {
    Write-Host "[setenv.ps1] value    : $value"
} else {
    Write-Host "[setenv.ps1] value required, exiting!"
    exit 101
}

if ($target) {
    Write-Host "[setenv.ps1] target   : $target"
} else {
	$target = 'user'
    Write-Host "[setenv.ps1] target   : $target (default)"
}

Write-Host
Write-Host "[setenv.ps1] [Environment]::SetEnvironmentVariable($variable, $value, $target)"
[Environment]::SetEnvironmentVariable($variable, $value, $target)

Write-Host
Write-Host "[setenv.ps1] ---------- stop -----------"
Write-Host