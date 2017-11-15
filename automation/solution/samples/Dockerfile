# DOCKER-VERSION 1.2.0
FROM microsoft/windowsservercore
MAINTAINER Jules Clements

# Copy solution, provision and then build
WORKDIR solution

COPY automation automation
COPY automation-solution/bootstrapAgent.ps1 automation-solution/bootstrapAgent.ps1

# Provision Build Dependancies
RUN automation\provisioning\runner.bat automation-solution\bootstrapAgent.ps1

# Default entry point, if build number not passed, will build using CDAF Emulator build counter
CMD automation\provisioning\runner.bat automation\remote\entrypoint.ps1
