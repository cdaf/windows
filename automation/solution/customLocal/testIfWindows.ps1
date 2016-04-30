
$ENVIRONMENT = $args[0]

if ( $ENVIRONMENT -eq 'WINDOWS' ) {
	Write-Host
	Write-Host "Environment is WINDOWS, perform test to verify deploy (remote) action, i.e. BUILDNUMBER should match"
	cat $TMPDIR/manifest.txt
 
} else {
	Write-Host
	Write-Host "Environment ($ENVIRONMENT) is not WINDOWS, therefore no action atempted"
 
}