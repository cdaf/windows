# Usage examples

# Windows 2016
# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'

# Download to named directory and add to path, without this, will simply download and extract in current directory
# $env:CDAF_INSTALL_PATH = 'c:\cdaf'

# Download specific published version, without this, or if set to Edge, will download latest from GitHub
# $env:CDAF_INSTALL_VERSION = '2.7.3'
# . { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/install.ps1 } | iex

Param (
	[string]$version
)

$scriptName = 'install.ps1'
cmd /c "exit 0"
$Error.Clear()


# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Warning "`n[$scriptName]$message"
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			Invoke-Expression $env:CDAF_ERROR_DIAG
		}
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

# Cater for "Access to the path is denied"
function moveOrCopy ($expression) {
    $Error.Clear()
    Write-Host "[$(Get-Date)] Move-Item $expression"
    try {
        Invoke-Expression "Move-Item $expression 2>`$null"
        if(!$?) { Write-Host "[moveOrCopy][MOVE_HALT] `$? = $?"; $error ; exit 1111 }
    } catch {
        ERRMSG "[moveOrCopy] Exception block move install of CDAF!"
    }
    if ( $error ) {
        Write-Host "[moveOrCopy][WARN] `$Error[] = $Error" -ForegroundColor Yellow
        $Error.Clear()
        try {
            Write-Host "[$(Get-Date)] Copy-Item -Recurse $expression"
            Invoke-Expression "Copy-Item -Recurse $expression 2>`$null"
            if(!$?) { Write-Host "[moveOrCopy][COPY_HALT] `$? = $?"; $error ; exit 1111 }
        } catch {
            ERRMSG "[moveOrCopy] Exception blocked copy install of CDAF!"
        }
        if ( $error ) {
            Write-Host "[moveOrCopy][ERROR] `$Error[] = $Error" -ForegroundColor Yellow
            $Error.Clear()
        }
    }
}

Write-Host "`n[$scriptName] --- start ---"
if ( $version ) {
    Write-Host "[$scriptName]   version     : $version"
} else {
	if ( $env:CDAF_INSTALL_VERSION ) {
		if ( $env:CDAF_INSTALL_VERSION -eq 'Edge' ) {
		    Write-Host "[$scriptName]   version     : (using edge from GitHub based on `$env:CDAF_INSTALL_VERSION)"
		} else {
			$version = $env:CDAF_INSTALL_VERSION
		    Write-Host "[$scriptName]   version     : $version (based on `$env:CDAF_INSTALL_VERSION)"
		}
	} else {
	    Write-Host "[$scriptName]   version     : (not passed, use edge from GitHub)"
	}
}

if ( $env:CDAF_INSTALL_PATH ) {
	$installPath = $env:CDAF_INSTALL_PATH
    Write-Host "[$scriptName]   installPath : $installPath (from `$env:CDAF_INSTALL_PATH)"
} else {
	$installPath = "$(pwd)\automation"
    Write-Host "[$scriptName]   installPath : $installPath (default)"
}

if ( Test-Path $installPath ) {
	executeExpression "Remove-Item -Recurse '$installPath'"
}

if ( $version ) {

	if ( Test-Path "$(pwd)\automation" ) {
		executeExpression "Remove-Item -Recurse '$(pwd)\automation'"
	}
	executeExpression "iwr -useb http://cdaf.io/static/app/downloads/WU-CDAF-${version}.zip -outfile WU-CDAF-${version}.zip"
	executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$(pwd)\WU-CDAF-${version}.zip', '$(pwd)')"
	moveOrCopy "'$(pwd)\automation' '${installPath}'"
	executeExpression "Remove-Item '$(pwd)\WU-CDAF-${version}.zip'"

} else {

	if ( Test-Path "$(pwd)\windows-master" ) {
		executeExpression "Remove-Item -Recurse '$(pwd)\windows-master'"
	}
	executeExpression "iwr -useb https://codeload.github.com/cdaf/windows/zip/refs/heads/master -outfile cdaf.zip"
	executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$(pwd)\cdaf.zip', '$(pwd)')"
	moveOrCopy "'$(pwd)\windows-master\automation\' '${installPath}'"
	executeExpression "Remove-Item -Recurse '$(pwd)\windows-master'"
	executeExpression "Remove-Item '$(pwd)\cdaf.zip'"

}

if ( $env:CDAF_INSTALL_PATH ) {
	executeExpression "${installPath}\provisioning\addPath.ps1 '${installPath}\provisioning'"
	executeExpression "${installPath}\provisioning\addPath.ps1 '${installPath}\remote'"
	executeExpression "${installPath}\provisioning\addPath.ps1 '${installPath}'"
}

executeExpression "${installPath}\remote\capabilities.ps1"

Write-Host "`n[$scriptName] --- end ---"
