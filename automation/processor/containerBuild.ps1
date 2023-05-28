Param (
	[string]$imageName,
	[string]$buildNumber,
	[string]$revision,
	[string]$action,
	[string]$rebuildImage,
	[string]$buildArgs
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

$scriptName = 'containerBuild.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[0] = $error"; exit 1113
		}
	}
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $imageName ) {
	Write-Host "[$scriptName]   imageName      : ${imageName} (passed, to be used in docker)"

	if ( $buildNumber ) { 
		Write-Host "[$scriptName]   buildNumber    : $buildNumber"
	} else {
		Write-Host "[$scriptName]   buildNumber    : (not supplied)"
	}
	
	if ( $revision ) { 
		Write-Host "[$scriptName]   revision       : $revision"
	} else {
		$revision = 'container_build'
		Write-Host "[$scriptName]   revision       : $revision (not supplied, set to default)"
	}
	
	if ( $action ) { 
		Write-Host "[$scriptName]   action         : $action"
	} else {
		$action = 'container_build'
		Write-Host "[$scriptName]   action         : $action (not supplied, set to default)"
	}
	
	if ( $rebuildImage ) {
		Write-Host "[$scriptName]   rebuildImage   : $rebuildImage (choices are yes, no or imageonly)"
	} else {
		$rebuildImage = 'no'
		Write-Host "[$scriptName]   rebuildImage   : $rebuildImage (not supplied, so set to default)"
	}
	
	if ( $buildArgs ) {
		Write-Host "[$scriptName]   buildArgs      : $buildArgs"
	} else {
		Write-Host "[$scriptName]   buildArgs      : (not supplied)"
	}
	
	$buildImage = "${imageName}_$($revision.ToLower())_containerbuild"
	Write-Host "[$scriptName]   buildImage     : $buildImage"
	Write-Host "[$scriptName]   DOCKER_HOST    : $env:DOCKER_HOST"
	Write-Host "[$scriptName]   pwd            : $(Get-Location)"
	Write-Host "[$scriptName]   hostname       : $(hostname)"
	Write-Host "[$scriptName]   whoami         : $(whoami)"

} else {
	Write-Host "[$scriptName]   imageName      : (not supplied, only process CDAF automation load)"
}

if ( Test-Path ".\automation" ) {
	if ( (Get-Item $env:CDAF_AUTOMATION_ROOT).FullName -ne "$($(pwd).Path)\automation" ) {
		executeExpression "Remove-Item -Recurse .\automation"
		executeExpression "Copy-Item -Recurse -Force $env:CDAF_AUTOMATION_ROOT .\automation"
		$cleanupCDAF = 'yes'
	} else {
		Write-Host "[$scriptName]   automationroot : .\automation`n"
	}
} else {
	if ( ((Get-Item $env:CDAF_AUTOMATION_ROOT).Parent).FullName -ne $(pwd).Path ) {
		Write-Host "[$scriptName]   automationroot : ${env:CDAF_AUTOMATION_ROOT} (copy to .\automation in workspace for docker)`n"
		executeExpression "Copy-Item -Recurse -Force $env:CDAF_AUTOMATION_ROOT .\automation"
		$cleanupCDAF = 'yes'
	} else {
		Write-Host "[$scriptName]   automationroot : ${env:CDAF_AUTOMATION_ROOT}`n"
	}
}

if ( $buildImage ) {
	Write-Host '$dockerStatus = ' -NoNewline 
	
	$imageTag = 0
	foreach ( $imageDetails in docker images --filter label=cdaf.${buildImage}.image.version --format "{{.Tag}}" ) {
		try {
			$imageDetailsTag = [INT]$imageDetails
			if ( $imageTag -lt $imageDetailsTag ) { $imageTag = $imageDetailsTag }
		} catch {
			# Ignore tags that are not integers
			$Error.Clear()
		}
	}
	if ( $imageTag ) {
		Write-Host "[$scriptName] Last image tag is $imageTag, new image will be $($imageTag + 1)"
	} else {
		$imageTag = 0
		Write-Host "[$scriptName] No existing images, new image will be $($imageTag + 1)"
	}

	if ( Test-Path Dockerfile ) {
		executeExpression "cat Dockerfile"
	} else {
		Write-Host "Dockerfile not found! Directory listing of $(pwd)"
		foreach ( $item in $(Get-ChildItem .) ) { Write-Host "  $item" }
	}
		
	if ( $rebuildImage -eq 'yes') {
		$otherOptions = " -rebuild $rebuildImage"
	}

	if ( $buildArgs ) {
		$otherOptions += " -optionalArgs '$buildArgs'"
	}

	executeExpression "$env:CDAF_AUTOMATION_ROOT/remote/dockerBuild.ps1 ${buildImage} $($imageTag + 1) $otherOptions"
	
	# Remove any older images	
	executeExpression "$env:CDAF_AUTOMATION_ROOT/remote/dockerClean.ps1 ${buildImage} $($imageTag + 1)"
	
	if ( $rebuildImage -ne 'imageonly') {
		# Retrieve the latest image number
		$imageTag = 0
		foreach ( $imageDetails in docker images --filter label=cdaf.${buildImage}.image.version --format "{{.Tag}}" ) {
			try {
				$imageDetailsTag = [INT]$imageDetails
				if ( $imageTag -lt $imageDetailsTag ) { $imageTag = $imageDetailsTag }
			} catch {
				# Ignore tags that are not integers
				$Error.Clear()
			}
		}
	
		Write-Host "[$scriptName] `$imageTag  : $imageTag"
		
		foreach ( $envVar in Get-ChildItem env:) {
			if ($envVar.Name.Contains('CDAF_CB_')) {
				${buildCommand} += " --env $(${envVar}.Name)=$(${envVar}.Value)"
			}
		}

		${prefix} = (${SOLUTION}.ToUpper()).replace('-','_')
		foreach ( $envVar in Get-ChildItem env:) {
			if ($envVar.Name.Contains("CDAF_${prefix}_CB_")) {
				${buildCommand} += " --env $(${envVar}.Name.Replace("CDAF_${prefix}_CB_", ''))=$(${envVar}.Value)"
			}
		}

		if ( $env:USERPROFILE ) {
			executeExpression "docker run --volume ${env:USERPROFILE}\:C:/solution/home --volume ${env:WORKSPACE}\:C:/solution/workspace ${buildCommand} ${buildImage}:${imageTag} automation\ci.bat $buildNumber $revision container_build"
		} else {
			executeExpression "docker run --volume ${env:WORKSPACE}\:C:/solution/workspace ${buildCommand} ${buildImage}:${imageTag} automation\ci.bat $buildNumber $revision container_build"
		}

		Write-Host "`n[$scriptName] List and remove all stopped containers"
		executeExpression "docker ps --filter `"status=exited`" -a"
		$stopped = docker ps --filter "status=exited" -aq
		if ( $stopped ) { 
			executeExpression "docker rm $stopped"
		}
	}
	
	if ( $cleanupCDAF ) {
		executeExpression "Remove-Item -Recurse .\automation"
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0
