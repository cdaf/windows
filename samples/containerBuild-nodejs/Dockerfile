# escape=`

ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Working directory should be absolute path
WORKDIR /solution

# Provision Build Dependancies
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
COPY automation-solution/bootstrapAgent.ps1 .
RUN .\bootstrapAgent.ps1

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR /solution/workspace

CMD ci
