Atomic Provisioning
===================
The intention of these provisioning scripts is that they are self container with minimal dependancies, i.e. can be executed on a clean OS.

Interactive Provisioning
------------------------

Role Installers cannot be run via remote powershell without spawning a new window. If running on the local machine and logging capture is desired, set the following environment variable.

[Environment]::SetEnvironmentVariable('interactive', 'true')