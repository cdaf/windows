Param (
	[String]$msiFile,
	[String]$opt_arg
)

$scriptName = 'installMSI.ps1'
cmd /c "exit 0"
$error.clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1011 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1012 }
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
			Write-Host "[$scriptName] `$error = $error"; exit 1013
		}
	}
}

function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$output = Invoke-Expression $expression
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
			Write-Host "[$scriptName] `$error = $error"; exit 1113
		}
	}
    return $output
}

Write-Host "`n[$scriptName] Generic MSI installer`n"
Write-Host "[$scriptName] ---------- start ----------"
if ($msiFile) {
    Write-Host "[$scriptName] msiFile          : $msiFile"
} else {
    Write-Host "[$scriptName] MSI file not supplied, exiting with error code 1"; exit 1
}

if ( Test-Path $msiFile ) {
	$fileName = Split-Path $msiFile -leaf
	$fullpath = (Get-Item $msiFile).FullName
} else {
	Write-Host "[$scriptName] $msiFile not found, exiting with error code 2"; exit 2
}

if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg          : $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg          : (not supplied)"
}

if ($env:interactive) {
    Write-Host "[$scriptName] `$env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

$logFile = $env:TEMP + '\' + $fileName + '.log'
Write-Host "[$scriptName] logFile          : $logFile"

if (Test-Path $logFile) { 
	Write-Host; executeExpression "Remove-Item $logFile"
}

if ( (Get-Item ((Get-Item $fullpath).Directory.FullName)).LinkType -eq 'SymbolicLink' ) {
	Write-Host "[$scriptName] $fullpath is in a symlink directory, copy to temp for execution"
	executeExpression "copy-item $fullpath $env:TEMP"
	$fullpath = "$env:TEMP\$fileName"
}

Write-Host
$argList = @(
	"/qn",
	"/L*V",
	"$logFile",
	"/i",
	"$fullpath",
	"$opt_arg"
)

# Perform Install
$proc = executeReturn "Start-Process -FilePath `'msiexec`' -ArgumentList `'$argList`' $sessionControl"
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed, see log file (c:\windows\logs\CBS\CBS.log) for details, listing last 40 lines`n"
	executeExpression "Get-Content 'c:\windows\logs\CBS\CBS.log' | select -Last 40"
	Write-Host "`n[$scriptName] Listing MSI log file`n"
	executeExpression "Get-Content $logFile"
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

$failed = Select-String $logFile -Pattern "Installation failed"
if ( $failed  ) { 
	Select-String $logFile -Pattern "Installation success or error status"
	exit 4
}

Write-Host "`n[$scriptName] ---------- stop ----------"
