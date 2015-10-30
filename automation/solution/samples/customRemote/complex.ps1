
Write-Host "custom script testing compatible commands:"
Write-Host
whoami
Write-Host
$TEST1 = $args[0]
$TEST2 = $args[1]

echo "Argument 1 is : $TEST1"
echo "Argument 2 is : $TEST2"
