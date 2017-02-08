# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

# This script is combined with the following in the Vagrantfile to offload the DC provisioning to this wrapper
#require 'vagrant-reload'
#Vagrant.configure(2) do |allhosts|
#  puts 'Use script wrapper to manage Domain Controller intermittent failures'
#  puts "vagrant action  = #{ARGV[0]}"
#  puts "first argument  = #{ARGV[1]}"
#  puts "second argument = #{ARGV[2]}"
#  result = system("./automation/provisioning/runner.bat ./automation/provisioning/dcProvision.ps1 #{ARGV[0]} #{ARGV[1]} #{ARGV[2]}")
#  puts "result        = #{result}"

$scriptName = 'dcProvision.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$vagrantAction = $args[0]
Write-Host "[$scriptName] vagrantAction : $vagrantAction"

$argument1 = $args[1]
Write-Host "[$scriptName] argument1     : $argument1"

$argument2 = $args[2]
Write-Host "[$scriptName] argument2     : $argument2"

$workDir = $(pwd)

executeExpression "cd dc-provisioning"

if ($vagrantAction -eq 'up') {

	if ((! $argument1) -or ($argument1 -eq 'dc')) {

		executeExpression "cat Vagrantfile"
		
		executeExpression "vagrant $vagrantAction $argument1 $argument2"
		executeExpression "vagrant $vagrantAction $argument1 $argument2"

		executeExpression "../automation/provisioning/winrmtest.ps1 172.16.17.102 vagrant vagrant 2 2"
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/newUser.ps1 deployer swUwe5aG yes"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/newUser.ps1 sqlData p4ssWord! yes"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/newUser.ps1 sqlSA p4ssWord!"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/newUser.ps1 sqlDBA p4ssWord!"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/setSPN.ps1 MSSQLSvc/DB:1433 SKY\SQLSA"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/setSPN.ps1 MSSQLSvc/db.sky.net:1433 SKY\SQLSA"'
		executeExpression 'vagrant powershell dc -c "/automation/provisioning/setenv.ps1 interactive yes User"'
		executeExpression 'vagrant powershell dc -c "/automation/remote/capabilities.ps1"'
		
	} else {
		Write-Host "[$scriptName] vagrantAction is up, but $argument1 is not dc or empty, so no action attempted."
	}
} else {
	executeExpression "vagrant $vagrantAction $argument1 $argument2"
    & vagrant status dc
}

executeExpression "cd $workDir"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
Write-Host
