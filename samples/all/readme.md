# All CDAF Core Features

To avoid execution of Remote Tasks

    $env:CDAF_DELIVERY='WORKGROUP'

To execute Remote Tasks, configure remote loop-back access to teh localhost.

    ..\..\automation\provisioning\mkdir.ps1 C:\deploy
    ..\..\automation\provisioning\CredSSP.ps1 server

    ..\..\automation\provisioning\trustedHosts.ps1 *
    ..\..\automation\provisioning\CredSSP.ps1 client