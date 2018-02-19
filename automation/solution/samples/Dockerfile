# DOCKER-VERSION 1.2.0
FROM microsoft/windowsservercore
MAINTAINER Jules Clements

# Copy solution, provision and then build
WORKDIR solution

COPY automation automation
COPY automation-solution/bootstrapAgent.ps1 automation-solution/bootstrapAgent.ps1

# Provision Build Dependancies
RUN automation\provisioning\runner.bat automation-solution\bootstrapAgent.ps1

CMD echo Usage: docker run --tty --volume ${workspace}\:C:/workspace ${imageName}:${imageTag} .\automation\processor\buildPackage.bat $buildNumber revision containerbuild
