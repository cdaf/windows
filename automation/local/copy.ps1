function taskException ($taskName, $exit, $exception) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($exception.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($exception.Exception.Message)" -ForegroundColor Red
	exit $exit
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split('\') 
	$NUMBEROFPIECES=$PIECES.Count 
	$FILENAME=$PIECES[$NumberOfPieces-1] 
	$DIRECTORYPATH=$FullPathName.Trim($FILENAME) 
	return $FILENAME

}

$copyFile         = $args[0]
$deployLand       = $args[1]
$WORK_DIR_DEFAULT = $args[2]

$fileName = getFilename($copyFile)

$scriptName = $myInvocation.MyCommand.Name 
$deployPath = "$deployLand\$fileName"

if ( Test-Path $WORK_DIR_DEFAULT\copyLand.ps1 ) {
	Remove-Item $WORK_DIR_DEFAULT\copyLand.ps1 -Recurse 
	if(!$?){ taskWarning "Remove-Item $WORK_DIR_DEFAULT\copyLand.ps1"}
}

# The copy method loads the file contents into an argument and streams to a remote writer, to get this to work,
# the target location needs to be a literal and cannot be substituted at runtime, to overcome this the script
# file itself is hardcoded with the desired target location.
$templateFile = @(Get-Content "$WORK_DIR_DEFAULT\copyTemplate.ps1")
$outputFile = "$WORK_DIR_DEFAULT\copyLand.ps1"
$stream = [System.IO.StreamWriter] $outputFile
foreach ($line in $templateFile) {
	$line = $line -replace "deployLand", $deployPath
	$line = $line -replace "copy.ps1", "copyLand.ps1"
	$stream.WriteLine($line)
}
$stream.close()

try {
	& $WORK_DIR_DEFAULT\copyLand.ps1 $copyFile
	if(!$?){ taskWarning }
} catch { taskException "$copyFile" 2491 $_ }
