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

$scriptName = 'registerMuleMMC.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

$MMC_GROUP = $args[0]
if ( $MMC_GROUP ) {
	Write-Host "[$scriptName] MMC_GROUP        : $MMC_GROUP"
} else {
	Write-Host "[$scriptName] MMC_GROUP not passed!"; exit 107
}

$tomcatHomeDir = $args[1]
if ( $tomcatHomeDir ) {
	Write-Host "[$scriptName] tomcatHomeDir    : $tomcatHomeDir"
} else {
	$tomcatHomeDir = 'C:\opt\apache-tomcat8-8.5.4'
	Write-Host "[$scriptName] tomcatHomeDir    : $tomcatHomeDir (default)"
}

$sourceInstallDir = $args[2]
if ( $sourceInstallDir) {
	Write-Host "[$scriptName] sourceInstallDir : $sourceInstallDir"
} else {
	$sourceInstallDir = 'c:\vagrant\.provision'
	Write-Host "[$scriptName] sourceInstallDir : $sourceInstallDir (default)"
}

Write-Host
Write-Host "[$scriptName] Load the MMC software"
executeExpression "Copy-Item `'$sourceInstallDir\mmc.war`' `'$tomcatHomeDir\webapps`'"

Write-Host
Write-Host "[$scriptName] Pause 10 seconds for MMC to load"
sleep 10

Write-Host

executeExpression "Copy-Item `'$sourceInstallDir\mmc\autorun.groovy $WINRM_HOSTNAME `'$tomcatHomeDir\bin`'"
executeExpression "Copy-Item `'$sourceInstallDir\mmc\setEnv.bat $WINRM_HOSTNAME `'$tomcatHomeDir\bin`'"
executeExpression "Copy-Item `'$sourceInstallDir\mmc\tomcat-users.xml $WINRM_HOSTNAME `'$tomcatHomeDir\conf`'"

function List-ServerGroups {
	param (	
	    [Parameter(Mandatory=$false)]
		[String]$url='http://localhost:8080/mmc'
	)	

    $result = [PSCustomObject]@{
                total = 0
                data = @()
            };
			
	try {
		$result = Invoke-RestMethod -Uri "$url/api/serverGroups" -Headers $Headers;				
	} catch {		
		Write-Host "ERROR" $_ -ForegroundColor red
		Return $result;
	}	
	
	return $result;
}

function muleRegisterServer {
	param (	
	    [Parameter(Mandatory=$false)]
		[String]$url='http://localhost:8080/mmc',
		
	    [Parameter(Mandatory=$true)]
		[String]$name,

	    [Parameter(Mandatory=$false)]
		[String]$agentUrl='http://localhost:7777/mmc-support',

	    [Parameter(Mandatory=$true)]
		[String]$groupId
	)	

	$request= @{
	    name = $name.ToUpper();
	    agentUrl = $agentUrl;
	    groupIds = @($groupId)
	};
	$jsonRequest = ConvertTo-Json -InputObject $request;
	
	$result=$null;

	try {
		## Write-Host "[DEBUG][muleRegisterServer] `$result = Invoke-RestMethod -Uri `"$url/api/servers`" -Body $jsonRequest -Headers `$Headers -ContentType `"application/json`" -Method POST;" -ForegroundColor Blue
		$result = Invoke-RestMethod -Uri "$url/api/servers" -Body $jsonRequest -Headers $Headers -ContentType "application/json" -Method POST;		
	} catch {		
		Write-Host "Registration failed, wait 30 seconds and then retry ..." $_ -ForegroundColor Yellow
		sleep 30
		try {
			## Write-Host "[DEBUG][muleRegisterServer] `$result = Invoke-RestMethod -Uri `"$url/api/servers`" -Body $jsonRequest -Headers `$Headers -ContentType `"application/json`" -Method POST;" -ForegroundColor Blue
			$result = Invoke-RestMethod -Uri "$url/api/servers" -Body $jsonRequest -Headers $Headers -ContentType "application/json" -Method POST;		
		} catch {		
			Write-Host "Registration failed" -ForegroundColor red
			throw $_ 
		}
	}	
	
	return $result	
}

$file = $tomcatHomeDir + '\conf\tomcat-users.xml'

Write-Host
Write-Host "  [RemotePowershell] Replace $token with `$value in $file"
(Get-Content $file | ForEach-Object { $_ -replace "$token", "$value" } ) | Set-Content $file
Write-Host

Write-Host
Write-Host "  [RemotePowershell] Start $tomcatServiceName Service >> "
try {
 	$service = Start-Service "$tomcatServiceName" -WarningAction SilentlyContinue -PassThru
 	if ($service.status -ine 'Running') {
 		Throw "Could not start service $tomcatServiceName"
 	} else {
		Write-Host
		Write-Host "    [RemotePowershell] $tomcatServiceName Service is $service.status"
 	}			
} catch {
 	Write-Error -Message "Unexpected Error. Error details: $_.Exception.Message"
 	Exit 1
}		
Write-Host
Write-Host "  [RemotePowershell] << Start $tomcatServiceName Service"

# Register the server
# At this stage, the Mule server is recognized by MMC, but it is unregistered
# so register the server
$user = 'admin'
$pass = 'admin'
$pair = "$($user):$($pass)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{Authorization = $basicAuthValue}
$serverName=($env:computername).ToUpper();
Write-Host
Write-Host "  [RemotePowershell] Register server name $serverName in MMC for environment $MMC_GROUP >>"
Write-Host
$foundGroup = $false;
(List-ServerGroups).data | ForEach-Object {
	## Write-Host "[DEBUG] `$_ = $_" -ForegroundColor Blue
    if ($_.name -ieq $MMC_GROUP) {
		try {
			Write-Host "    [RemotePowershell] muleRegisterServer -name $serverName -groupId $_.id ($MMC_GROUP)"
            muleRegisterServer -name $serverName -groupId $_.id;      
		} catch {
			Write-Host "[RemotePowershell] muleRegisterServer threw exception!" -ForegroundColor Red
			throw $_
		}	
        $foundGroup=$true;
    }
}

if(-not $foundGroup) {
    throw "[RemotePowershell] Couldn't find a server group for the environment"
}
Write-Host
Write-Host "  [RemotePowershell] << Register server name $serverName in MMC for environment $MMC_GROUP"

Write-Host
Write-Host "    [Install-MuleMMC.ps1] < Configure via Remote PowerShell"
Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
