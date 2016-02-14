function taskException ($taskName, $exit, $exception) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($exception.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($exception.Exception.Message)" -ForegroundColor Red
	exit $exit
}

$srcPath   = $args[0]

$scriptName = $myInvocation.MyCommand.Name 
if (-not(Test-Path $srcPath)) {

	write-host
	write-host "[$scriptName] Source file not found! Throwing exception : $srcPath" -ForegroundColor Red
	write-host
    throw "$srcPath"
}

Write-Host
Write-Host "[$scriptName] Copy $srcPath to 'deployLand'"
Write-Host
try {
    [System.IO.FileStream]$srcStream = New-Object IO.FileStream $srcPath, Open
    [Byte[]]$readBuffer  = New-Object Byte[]  1048576 #  1MB

    do {

		# Read from the input file and create a resulting buffer to the exact length of the stream
        $streamLength = $srcStream.Read($readBuffer, 0, $readBuffer.Length)
		[Byte[]] $buffer = New-Object Byte[] $streamLength
		for ($index = 0; $index -lt $streamLength; $index += 1) {
			$buffer[$index] = $readBuffer[$index]
		}

		# Process each buffer on the target host
		Invoke-Command -Session $session `
		-ScriptBlock { 
			param(
				[Byte[]] $inBuffer
			)

			try {
				[System.IO.FileStream]$dstStream = New-Object IO.FileStream 'deployLand', Append
				$dstStream.Write($inBuffer, 0, $inBuffer.length)
			} catch {
				taskException "BUFFER_WRITE" 201 $_
			} finally {
				$dstStream.Dispose()
				$dstStream = $null

# I don't think this is needed, so commented out unless I see a remote session fail
#				[System.GC]::Collect()
			}
		} `
		-ArgumentList @( ,$buffer )

    } while ($streamLength -gt 0)

} catch {
	taskException "BUFFER_READ" 200 $_
} finally {

    $srcStream.Dispose()
    $srcStream = $null

    [System.GC]::Collect()
}
