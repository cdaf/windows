function ExitWithCode { 
    param ($exitcode)
    write-host
    $host.SetShouldExit($exitCode)
    exit
}

function taskComplete { param ($taskName)
    write-host
    write-host "[$scriptName] Remote Task ($taskName) Successfull " -ForegroundColor Green
    write-host
}

$scriptName = $myInvocation.MyCommand.Name 

# Enable IIS features before installing Web Deploy
dism /online /enable-feature /featurename:IIS-WebServerRole 
dism /online /enable-feature /featurename:IIS-WebServerManagementTools
dism /online /enable-feature /featurename:IIS-ManagementService
Reg Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1
net start wmsvc
