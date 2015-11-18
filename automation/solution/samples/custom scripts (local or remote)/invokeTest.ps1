
$argument1 = $args[0]
$argument2 = $args[1]
$argument3 = $args[2]

$scriptName = $myInvocation.MyCommand.Name 

Write-Host
Write-Host "[$scriptName]  argument1 : $argument1"
Write-Host "[$scriptName]  argument2 : $argument2"
Write-Host "[$scriptName]  argument3 : $argument3"
