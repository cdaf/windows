
$DIRECTORY = $args[0]

if ($args[1] ) {
	$FILE = $args[1]
} else {
	$FILE = $DIRECTORY 
}

$scriptName = $myInvocation.MyCommand.Name

# this is not finished
Write-Host get-content $DIRECTORY\$FILE | convertto-securestring
