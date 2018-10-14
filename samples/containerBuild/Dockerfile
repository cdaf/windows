# DOCKER-VERSION 1.2.0
FROM microsoft/windowsservercore
MAINTAINER Jules Clements

# Copy solution, provision and then build
WORKDIR solution

COPY automation automation
COPY automation-solution/bootstrapAgent.ps1 automation-solution/bootstrapAgent.ps1

# Provision Build Dependancies
RUN automation\provisioning\runner.bat automation-solution\bootstrapAgent.ps1

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR workspace

CMD echo Usage: docker run --tty --volume ${workspace}\:C:/solution/workspace ${imageName}:${imageTag} automation\processor\buildPackage.bat $buildNumber revision containerbuild
