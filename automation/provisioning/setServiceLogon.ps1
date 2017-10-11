Param (
  [string]$userDomain,
  [string]$userAlias
)
$scriptName = 'addFeature.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($userDomain) {
    Write-Host "[$scriptName] userDomain   : $userDomain"
} else {
    Write-Host "[$scriptName] userDomain not passed, exit with LASTEXITCODE 100"; exit 100
}

if ($userAlias) {
    Write-Host "[$scriptName] userAlias   : $userAlias"
} else {
    Write-Host "[$scriptName] userAlias not passed, exit with LASTEXITCODE 101"; exit 101
}

#Desc: Grants log on as service rights on the computer. This script needs to run in elevated mode (admin)
#created by: Sachin Patil

$scriptPath = (Get-Location).Path

$infFile =  Join-Path $scriptPath "GrantLogOnAsService.inf"
$logFile = Join-Path $scriptPath "OutputLog.txt"
if(Test-Path $infFile) {
    Remove-Item -Path $infFile -Force
}

$objUser = New-Object System.Security.Principal.NTAccount($userDomain, $userAlias)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$sid = $strSID.Value

#NT Service/ALL SERVICES
$objUser2 = New-Object System.Security.Principal.NTAccount("NT SERVICE", "ALL SERVICES")
$strSID2 = $objUser2.Translate([System.Security.Principal.SecurityIdentifier])
$sid2 = $strSID2.Value

Write-Host "User SID: $sid"
Write-Host "Creating template file $infFile"

Add-Content $infFile "[Unicode]"
Add-Content $infFile "Unicode=yes"
Add-Content $infFile "[Version]"
Add-Content $infFile "signature=`"`$CHICAGO$`""
Add-Content $infFile "Revision=1"
Add-Content $infFile "[Registry Values]"
Add-Content $infFile "[Profile Description]"
Add-Content $infFile "Description=This is security template to grant log on as service access"
Add-Content $infFile "[Privilege Rights]"
Add-Content $infFile "SeServiceLogonRight = *$sid,*$sid2" #add more users here if needed

$seceditFile = "c:\Windows\security\database\secedit.sdb"
#Make sure it exists
if((Test-Path $seceditFile) -eq $false)
{
    Write-Error "Security database does not exist $seceditFile"
}
write-host "Validating new security template .inf file"
#validate if template is correct
secedit /validate $infFile
$exitcode = $LASTEXITCODE
if($exitcode -ne 0)
{
    Write-Error "Error in validating template file, $infFile exit code $exitcode"
    exit $exitcode
}

write-host "Appliying security template to default secedit.sdb"

secedit /configure /db secedit.sdb /cfg "$infFile" /log "$logFile"
$exitcode = $LASTEXITCODE
if($exitcode -ne 0)
{
    Write-Error "Error in secedit call, exit code $exitcode"
    exit $exitcode
}
get-content "$logFile"
write-host "Successfully granted log on as service access to user $userAlias" -ForegroundColor Green
gpupdate /force

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
