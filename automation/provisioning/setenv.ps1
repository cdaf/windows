$scriptName = 'setenv.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$variable = $args[0]
$value    = $args[1]
$target   = $args[2]

# vagrant file share is dependant on provider, for VirtualBox, pass as C:\vagrant\.provision
if ($variable) {
    Write-Host "[$scriptName] variable : $variable"
} else {
	$mediaDir = '/vagrant/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($value) {
    Write-Host "[$scriptName] value    : $value"
} else {
    Write-Host "[$scriptName] value required, exiting!"
    exit 101
}

if ($target) {
    Write-Host "[$scriptName] target   : $target"
} else {
	$target = 'user'
    Write-Host "[$scriptName] target   : $target (default, choices user or machine)"
}

Write-Host
Write-Host "[$scriptName] [Environment]::SetEnvironmentVariable($variable, $value, $target)"
[Environment]::SetEnvironmentVariable($variable, $value, $target)

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host