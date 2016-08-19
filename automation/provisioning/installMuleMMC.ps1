Write-Host
Write-Host "[Install-MuleMMC.ps1] ---------- start ----------"
Write-Host

if ( $args[0] ) {
	$vmHost = $args[0]
	Write-Host "[Install-MuleMMC.ps1] vmHost                : $vmHost"
} else {
	Write-Host "[Install-MuleMMC.ps1] VM host not passed!"; exit 100
}
if ( $args[1] ) {
	$username = $args[1]
	Write-Host "[Install-MuleMMC.ps1] username              : $username"
} else {
	Write-Host "[Install-MuleMMC.ps1] Username not passed!"; exit 101
}
if ( $args[2] ) {
	$userpass = $args[2]
	Write-Host "[Install-MuleMMC.ps1] userpass              : ***********"
} else {
	Write-Host "[Install-MuleMMC.ps1] Password not passed!"; exit 102
}

if ( $args[3] ) {
	$sourceInstallDir = $args[3]
	Write-Host "[Install-MuleMMC.ps1] sourceInstallDir      : $sourceInstallDir"
} else {
	Write-Host "[Install-MuleMMC.ps1] sourceInstallDir not passed!"; exit 103
}

if ( $args[4] ) {
	$destinationInstallDir = $args[4]
	Write-Host "[Install-MuleMMC.ps1] destinationInstallDir : $destinationInstallDir"
} else {
	Write-Host "[Install-MuleMMC.ps1] destinationInstallDir not passed!"; exit 104
}

if ( $args[5] ) {
	$tomcat_version = $args[5]
	Write-Host "[Install-MuleMMC.ps1] tomcat_version        : $tomcat_version"
} else {
	Write-Host "[Install-MuleMMC.ps1] tomcat_version not passed!"; exit 105
}

if ( $args[6] ) {
	$mule_mmc_version = $args[6]
	Write-Host "[Install-MuleMMC.ps1] mule_mmc_version      : $mule_mmc_version"
} else {
	Write-Host "[Install-MuleMMC.ps1] mule_mmc_version not passed!"; exit 106
}

if ( $args[7] ) {
	$MMC_GROUP = $args[7]
	Write-Host "[Install-MuleMMC.ps1] MMC_GROUP             : $MMC_GROUP"
} else {
	Write-Host "[Install-MuleMMC.ps1] MMC_GROUP not passed!"; exit 107
}

if ( $args[8] ) {
	$passwordFile = $args[8]
	Write-Host "[Install-MuleMMC.ps1] passwordFile          : $passwordFile"
} else {
	Write-Host "[Install-MuleMMC.ps1] passwordFile not passed!"; exit 108
}

if ( $args[9] ) {
	$certificateThumb = $args[9]
	Write-Host "[Install-MuleMMC.ps1] certificateThumb      : $certificateThumb"
}

Write-Host

Write-Host "  [Install-MuleMMC.ps1] Provision via Remote PowerShell >"
Write-Host
# Create a credential object with the user ID and userpass
$securePassword = ConvertTo-SecureString $userpass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

$tomcatServiceName="Tomcat8";
$tomcatHomeDir = "$destinationInstallDir\apache-tomcat-$tomcat_version"

$argList = @( "$sourceInstallDir", "$destinationInstallDir", "$tomcat_version", "$tomcatHomeDir", "$mule_mmc_version", "$tomcatServiceName")

try {
	Invoke-Command -ComputerName $vmHost -credential $cred -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck) -ArgumentList $argList {
		if ( $args[0] ) {
			$sourceInstallDir = $args[0]
			Write-Host "  [RemotePowershell] sourceInstallDir      : $sourceInstallDir"
		} else {
			throw "[RemotePowershell] sourceInstallDir not passed"
		}
		
		if ( $args[1] ) {
			$destinationInstallDir = $args[1]
			Write-Host "  [RemotePowershell] destinationInstallDir : $destinationInstallDir"
		} else {
			throw "[RemotePowershell] destinationInstallDir not passed"
		}

		if ( $args[2] ) {
			$tomcat_version = $args[2]
			Write-Host "  [RemotePowershell] tomcat_version        : $tomcat_version"
		} else {
			throw "[RemotePowershell] tomcat_version not passed"
		}

		if ( $args[3] ) {
			$tomcatHomeDir = $args[3]
			Write-Host "  [RemotePowershell] tomcatHomeDir         : $tomcatHomeDir"
		} else {
			throw "[RemotePowershell] tomcatHomeDir not passed"
		}

		if ( $args[4] ) {
			$mule_mmc_version = $args[4]
			Write-Host "  [RemotePowershell] mule_mmc_version      : $mule_mmc_version"
		} else {
			throw "[RemotePowershell] mule_mmc_version not passed"
		}

		if ( $args[5] ) {
			$tomcatServiceName = $args[5]
			Write-Host "  [RemotePowershell] tomcatServiceName     : $tomcatServiceName"
		} else {
			throw "[RemotePowershell] tomcatServiceName not passed"
		}

		Write-Host
		Write-Host '  [RemotePowershell] Provision Tomcat 8 (as service) >>'
		
		# Create the installation directory for Tomcat
		try {
			New-Item -path $tomcatHomeDir -type directory -force | Out-Null
		} catch {
			Write-Host "Unexpected Error. Error details: $_.Exception.Message"
			throw $_
		}		
		Write-Host "    Folder installation: $tomcatHomeDir"
		
		# Install Tomcat as a Windows Service
		$apacheTomcatInstallFileName="apache-tomcat-" + $tomcat_version + ".exe";
		Write-Host "    Installing Tomcat as Windows Service ..."
		try {
			Start-Process "$sourceInstallDir\$apacheTomcatInstallFileName" -ArgumentList "/S /D=$tomcatHomeDir" -Wait
			Start-Process "$tomcatHomeDir\bin\Tomcat8.exe" -ArgumentList "//US//$tomcatServiceName --Startup=Auto" -Wait
		} catch {
			Write-Host "Unexpected Error. Error details: $_.Exception.Message"
			throw $_
		}		
		Write-Host '  [RemotePowershell] << Provision Tomcat 8 (as service)'
		Write-Host
		
		Write-Host "  [RemotePowershell] Configuring environment variables >>"
		Write-Host
		Write-Host "    [System.Environment]::SetEnvironmentVariable(`"CATALINA_HOME`", `"$tomcatHomeDir`", `"Machine`")"
		[System.Environment]::SetEnvironmentVariable("CATALINA_HOME", "$tomcatHomeDir", "Machine")
		
		$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
		Write-Host "    [System.Environment]::SetEnvironmentVariable(`"PATH`", $pathEnvVar + `";$tomcatHomeDir\bin`", `"Machine`")"
		[System.Environment]::SetEnvironmentVariable("PATH", $pathEnvVar + ";$tomcatHomeDir\bin", "Machine")
		Write-Host
		Write-Host "    Copy MMC (will not deploy because tomcat is not running ..."
		Write-Host
		Copy-Item "$sourceInstallDir\mmc-console-$mule_mmc_version.war" "$tomcatHomeDir\webapps\mmc.war"

		Write-Host
		Write-Host "  [RemotePowershell] << Configure environment variables"
		Write-Host

	}	
    if(!$?) { Write-Host "[Install-MuleMMC.ps1] Invoke Failure!! exit 200"; exit 200 }
} catch { Write-Host "[Install-MuleMMC.ps1] Invoke Exception thrown, $_ exit 201"; exit 201 }

Write-Host "  [Install-MuleMMC.ps1] < Provision via Remote PowerShell "
Write-Host

Write-Host "  [Install-MuleMMC.ps1] Copy Configuration files to VM >"
Write-Host
Write-Host "    [Install-MuleMMC.ps1] Send configuration files to $muleInstallDir"
Write-Host
$workingDirectory = $(pwd)

& .\remoteCopy.ps1 $workingDirectory\configs\tomcat\autorun.groovy $WINRM_HOSTNAME "$tomcatHomeDir\bin" $username $userpass 
& .\remoteCopy.ps1 $workingDirectory\configs\tomcat\setEnv.bat $WINRM_HOSTNAME "$tomcatHomeDir\bin" $username $userpass 
& .\remoteCopy.ps1 $workingDirectory\configs\tomcat\tomcat-users.xml $WINRM_HOSTNAME "$tomcatHomeDir\conf" $username $userpass

Write-Host
Write-Host "    [Install-MuleMMC.ps1] < Copy Configuration files to VM"
$mmcPass = ./decryptKey.ps1 cryptLocal\$passwordFile $certificateThumb

Write-Host
Write-Host "    [Install-MuleMMC.ps1] Configure via Remote PowerShell >"
Write-Host

$argList = @( "$sourceInstallDir", "$destinationInstallDir", "$MMC_GROUP", "$tomcatHomeDir", "$mule_mmc_version", "$tomcatServiceName", "@MMC_PASSWORD@", "$mmcPass")

try {
	Invoke-Command -ComputerName $vmHost -credential $cred -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck) -ArgumentList $argList {
		if ( $args[0] ) {
			$sourceInstallDir = $args[0]
			Write-Host "  [RemotePowershell] sourceInstallDir      : $sourceInstallDir"
		} else {
			throw "[RemotePowershell] sourceInstallDir not passed"
		}
		
		if ( $args[1] ) {
			$destinationInstallDir = $args[1]
			Write-Host "  [RemotePowershell] destinationInstallDir : $destinationInstallDir"
		} else {
			throw "[RemotePowershell] destinationInstallDir not passed"
		}

		if ( $args[2] ) {
			$MMC_GROUP = $args[2]
			Write-Host "  [RemotePowershell] MMC_GROUP             : $MMC_GROUP"
		} else {
			throw "[RemotePowershell] MMC_GROUP not passed"
		}

		if ( $args[3] ) {
			$tomcatHomeDir = $args[3]
			Write-Host "  [RemotePowershell] tomcatHomeDir         : $tomcatHomeDir"
		} else {
			throw "[RemotePowershell] tomcatHomeDir not passed"
		}
		
		if ( $args[4] ) {
			$mule_mmc_version = $args[4]
			Write-Host "  [RemotePowershell] mule_mmc_version      : $mule_mmc_version"
		} else {
			throw "[RemotePowershell] mule_mmc_version not passed"
		}

		if ( $args[5] ) {
			$tomcatServiceName = $args[5]
			Write-Host "  [RemotePowershell] tomcatServiceName     : $tomcatServiceName"
		} else {
			throw "[RemotePowershell] tomcatServiceName not passed"
		}
		
		if ( $args[6] ) {
			$token = $args[6]
			Write-Host "  [RemotePowershell] token                 : $token"
		} else {
			throw "[RemotePowershell] token not passed"
		}
		
		if ( $args[6] ) {
			$value = $args[7]
			Write-Host "  [RemotePowershell] value                 : ************* "
		} else {
			throw "[RemotePowershell] value not passed"
		}

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

	}
    if(!$?) { Write-Host "[Install-MuleMMC.ps1] List and Register MMC Failure!!"; exit 200 }
} catch {
	Write-Host "[Install-MuleMMC.ps1] List and Register MMC exception :" 
	Write-Host "$_" 
	exit 201 
}
Write-Host
Write-Host "    [Install-MuleMMC.ps1] < Configure via Remote PowerShell"
Write-Host
Write-Host "[Install-MuleMMC.ps1] ---------- stop -----------"
Write-Host
