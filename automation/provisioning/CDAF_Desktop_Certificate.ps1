Param (
  [string]$location,
  [string]$placement,
  [string]$certPath,
  [string]$pfxPassword
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'CDAF_Desktop_Certificate.ps1'
# Extension to capture output and return for use in variables
function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$output = Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][EXCEPTION] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][EXIT] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
    return $output
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][EXCEPTION] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][EXIT] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
}

Write-Host "`n[$scriptName] Requires elevated privilages"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($location) {
  Write-Host "[$scriptName] location    : $location (CurrentUser or LocalMachine)"
} else {
  $location = 'CurrentUser'
  Write-Host "[$scriptName] location    : $location (default)"
}

if ($placement) {
  Write-Host "[$scriptName] placement   : $placement (e.g. My, WebHosting)"
} else {
  $placement = 'My'
  Write-Host "[$scriptName] placement   : $placement (default)"
}

if ($certPath) {
  Write-Host "[$scriptName] certPath    : $certPath (must be absolute path)"
} else {
  Write-Host "[$scriptName] certPath    : (not supplied, must be absolute path)"
}

if ($pfxPassword) {
  Write-Host "[$scriptName] pfxPassword : $pfxPassword"
} else {
  Write-Host "[$scriptName] pfxPassword : (not supplied, will install 'well known' CDAF certificate)"
}

if ($pfxFile) {
  Write-Host "`n[$scriptName] Import the certificate from encoded content"
  $EncodedText = 'MIINIgIBAzCCDN4GCSqGSIb3DQEHAaCCDM8EggzLMIIMxzCCBhgGCSqGSIb3DQEHAaCCBgkEggYFMIIGATCCBf0GCyqGSIb3DQEMCgECoIIE/jCCBPowHAYKKoZIhvcNAQwBAzAOBAiU3vgkhhFx8AICB9AEggTYx2JJuNV9Jm1+5KOl4b6BVirODL7n/NNPCX/WZUEfZ4zS8fHXQiG/YT9wAcAOk7HnfrRlxgYdmhCUzdLkUGbAWfCEiyrvAwBe3lQOMaI0nfpRZTJXlAhCzBe3NlEZhUunOg9/i9uFrodc12MhrSkyotdR97xT2e+MMgj42rQ7Z8+YnNz8b6VVMf63KZMfF8Ft6UAk65zaI6R4tav2O9iJYG8cjIfHtdD1DDvK/OKg86Af7R34TrrxJ/LI3uU4ql9El/ZcGRKKms9U37m2oMLmmvwSpFpKS0cmkNd2/f0isngW8t5onqqJ+shxLwvTdi/CHM0ImH7pHbTEsROM0nrkqltBhyyWrjklqTiByKgrWMGWAhNB1vfxA1/szkDEEfXNFYOrkAUvyrYzV2kxH1NjSt6H12+SfInx+HUV8Ult/thlgCOxHjNnjolsHUMv+0yNwlR887lZe415eFB/Ew7FGi9SLNEP6lZefr907wU4eLPVcBqBZ+j1SA7sBGshqyXSNq1caGZ2r+hYAw/YSXXGewjw/k6A9ZZ7ZXSJzWBFl+WCLS0KHdj1syjAPz1RKWoJksmmt1cSx+jh0uUSBZDcKi8qmuZULF6E21qfaeMQ/8uAPXb2kI/v9sXsU+ia7+S94Fny3Vuhzm5LIm652frwyLQP+FJmo3NKunYQljKuNKgt9BcmzVKw2yggG519IbpMdBi5ARgvV/vPRyE/QLC7nRkwKX8nEP2qcSoID65me84lXSbReh5DhYxlWEHd0XvxNvENZ68T28dJgCaICoF3MB3eU3C6KpsvvjdC5A6Dx2YTBagsyKOTYiN/EyOgeuXrPULH1SqcLnU/KF1kc4Btt9wAivXJ22dfod00RxchQwJ4LNrSIx+XwrE6ZbqJQ+nv0O6c3ooyV9itkaitZ2nnZCJHOD6dkAeB2zaKTTUz26Kvfmg0nzTRqXzy803MijEhNsUCy327ZFkD7LBMxZHXQHtTH2Kmg0M6XIk0dGllorDgDBwr3dq8POlVCJPu900YxyU7axDErScEDpZ7S6p350hCiLnlCgE6reHq4RL1ALStmWMT4aM/UXEdAqGDKlpI5oygFLJsY15q1V9FpkW86gN3D+se1nnHMk3SsqA8MwekPpyhvCvm6okxROnypxa10ox7sW2LQDnemmhE5SJABirZCWaxGcc/uSlx4zE9yUaq2UqTRWZRg1Lds7XirRHwcKdcjrA6c55i68Xc5UKNh1eTWLj8qa8vXPgt4QiA79fqNEzmwvFaA24H2HwER0wPSnK0EDquglOMeHsbRt0R03f/nh4OdVO7WOajrD8GYoxhplwS22sODWPvltfeSUfJ6ZGB6E7q6YG3p0VFQ1PeYQcggZCiTRj4B9x6e7zePi8d4Tkxe9zVWmFA1vERgxCsHvSY+MB5rSkJ1izSbEigyCFtZ3sz+LtAK8FAWkMjaLfWbdjFqztBJ538qMEZs4UVf0ayOnPaLFp25IyrWZxCTTlnabNTEvPORea400+fsn36o+ptlUoXpvn8I5fxQX2XhUhNW0PlFCgy1aMsnJd55qayTBlC7ZcPCW5kSmaDlqoxgmSv75V+rK3Cp5pQj5kFixHxPmmDewMX61Gh8REVLx1KivQgwTWZCgy/u2M3zzsChAUnBUN0LDGB6zATBgkqhkiG9w0BCRUxBgQEAQAAADBnBgkqhkiG9w0BCRQxWh5YAGwAZQAtAFUAcwBlAHIALQA0ADAAMgBiAGIANwA2ADMALQA0ADQANAA1AC0ANAA5ADcANQAtAGIANwBmADIALQAyADMAYgBlADAAYwA1ADQAYwAyAGMAMTBrBgkrBgEEAYI3EQExXh5cAE0AaQBjAHIAbwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAgAHYAMQAuADAwgganBgkqhkiG9w0BBwagggaYMIIGlAIBADCCBo0GCSqGSIb3DQEHATAcBgoqhkiG9w0BDAEGMA4ECPfpl0sMjDX1AgIH0ICCBmCXAotOOsYiMTQ0ohLwhD7hqDz6/nNqcZYx2BqYYE7+yG1/RYBkY2ns+tm5ZV3S/eU3+FeXKjfbBnAtk1GrCzEsJDIDqPH0HKzgKsGfVeSvzPiRi/8H6b4AHIJI1YTCTr4KRimr9xWfaJ9xxrGtv5AeXBhDGrrf6diATRmYI/OZ7akRbzBpD+SbmuKvUspBpjv1O0RJXWe1MsBKvgkGW+fAZ1ZtVD11+ByQe2W/b4Dpjr5tmxur5fxnEpNXRCUrMQFjzkuwaaerUW3dmhmQ5ZXNv335ramfUL03hVL+o1muXvRKxnCejlpvmKyyJlqzpXWUSQrCxNFsq8iNRdu1BQDyCVOQ3Iwa1LMeHxoaJAegIcfdi5SrKHOUf4W/f3gVj/Z5GONsZESO77lY2AGW+pqvKLtULc9d5KI6g9Rq2UG1DBmVqrnAFuzAfFe1l8VDUwOkiCwL/ZK1UzS24eyM/B07rtPsbLREongREHLTWEZkJhMPboXpBlm/Vlupv2h9tY6FcCnQKeykeYhmOJuW3q0/vIzTgrd6pZNNDUziOmMYL7q/iENwQPLS4NQnBkcBdcinkWxmfIiDentNowBBKR/x/nLFN0kEFpJ9XwBctlKDKrUhQCD8EZJQ8aCqlvRauNA210zZPeIvmryn+bSdOH0LlnZN/aGqwBxXNYdaQkKzuLdcMFHDdewBqdYLENzWSqV+5mZBRcr/7yqpiZQv8GeE7WY7qL1UkzehvJb8CLpMRI0c4P5IoULWdVAg3m0Z7JAJYqz+OY58pPKeyybSSVOEVY5bUqgbJZvU3OVUSo+JEg48zgX+XptxIIF8d6HVNxhfYhtBpvkkIv79ocLeoKJh0LPmUptJHOVcxn1rFXuhN5nEzAZlDFKY+3jCQ8tHaKCwp9P2R0Ro9vBiAMX6dnRAKhW1UhHYUDVypqvuRiJrV1fuWiVj8JH4grrrJAtWgPlX9I9c+saWOEyobTbmzougq9Tx3rjZ92y6sPwYS0tk9S5ZD+u4heZdEv9+5W6uPEYPKJkwRSjpK1vzBT9xrpvYgcvi4SJ9oJkClyRm8sN1xU5WhlOSykMEl5jhQPJ9xJazCaPHlTKLqQhGVGZoIGeqaC+hmTB8mWtQ3lfTG9xcWD0J3XiFWflevI9W7U+WCU+Kg7c9JPkt/n1I4QjWi/wXjAMgLZztBs+WU1GQcpqwcWGqaILs0BIwAwLrHnZ3j1Xs38cKJYJam9TRr0s5vNEgkhMJ+LoejuQ43XfK0KX+7ldTTTrfvIpbp0BXK6ui2d/FQ5ceMWMp6bX3GFW8mt7EBFCoVd8G11bnr96MzDrnbkvNMvCUXonNMiU8n7tt/Y06qjpbAbtoOGA4grmFs1xfXYY5eAgKpcvxX9dBwNxxZaesHpq6f7xS4tvhY1VjscpnJF0N1TzQ3DpNtZC10bbQ6ZmZYZNejOQREe1NkdZGaf6Jy0bhW6ijUuJPBGSn2VCXcmXbciqYUGNkCo8VVjRu4C2nMArcVXkj2dxrS2L29u4YE71wFaQ+QHx1LwAxnysl9BiqFC7JKfWT9ZbeFJRdrd9JPCnAm/k3miSy1C4VthmFQP9BiQ8YjlUpoOIaV68kHqoPIcEDbVUtyBq88/2fJykZy4LyXTH4CEis/VJXyIgITUVwYDQpq/fyBdpJLiMLh70J3/b41oTdjSyHSFqKjSju3GEvUaNBsu3YmNq4WqQiW4qIJ2seexYbycVTNScGLn0XSjnpKu/1fEGrG0Rh26xHvzpn1ZtBGc4pvILVlsLkq4UTu2l0XMMR2jtL987CU92Se0j+WeG84atD/X2wCWHwUFk3yejg06vqj/3W1Gxkq4pzu/+OUsXy8oK1cI0Bk28zxTS4uHY6npJBCLfeeo4BJ90v/BYPtFBgEwjWdi2j4BLBqAaR3a0KBX/21TSJ3mmBrf1NhijbeaZyVEP7ZWRg2eu4LdTf5np7cc1k01F+V998i0VLEUa0iDbtMTpC8VxX4wQb1objFCCamPMU/bgjTuxeWXk//I6RmPy+kSAf9M2OzNTEvlW777ELBRY/pvMmdWzVg9nou9icSbIOUTMTuRTPS09C/qW27kz5j1IGvw9QhI5pz/R9GThdL1fPiK6hA5IbCzyQ2jPg3p+6EECqjPR1HLW0a1kVELvWV/CaIVqMWG/LoWhhmuP0sFIwOzAfMAcGBSsOAwIaBBTd4kCU6sPH0x9EjSaXddKEYD572AQUoeW+/zR2OiO5yFFV7tvOTv05gGICAgfQ'
  $ByteArray = [System.Convert]::FromBase64String($EncodedText)

  # Create an object for the certificate
  $pfx = executeReturn 'new-object System.Security.Cryptography.X509Certificates.X509Certificate2'
  executeExpression '$pfx.import($ByteArray , "password", "Exportable,PersistKeySet")'
} else {
  executeExpression "`$pfx.Import('$certPath', $pfxPassword, 'Exportable, PersistKeySet')"
}

Write-Host "`n[$scriptName] Access the store ($location\$placement)"
$store = executeReturn "new-object System.Security.Cryptography.X509Certificates.X509Store('$placement', '$location')"
executeExpression '$store.open("MaxAllowed")'
executeExpression '$store.add($pfx)'
executeExpression '$store.close()'

Write-Host "`n[$scriptName] Import complete"
executeExpression "Get-ChildItem -path cert:\$location\$placement"

Write-Host "`n[$scriptName] ---------- stop -----------"
$error.clear()
exit 0