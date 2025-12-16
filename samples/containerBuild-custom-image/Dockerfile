# escape=`
# Allow override of image as environment variable
ARG CONTAINER_IMAGE=docker.io/cdaf/linux:windows
FROM ${CONTAINER_IMAGE}

# Create root, i.e. C:\solution
WORKDIR /solution

# Shared bootstrap between Docker and Vagrant
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
RUN base.ps1 netfx-4.8-devpack

# If not using the CDAF base image
# RUN curl.exe -fsO "https://raw.githubusercontent.com/cdaf/windows/refs/heads/master/provisioning/base.ps1"
# RUN ./base.ps1 netfx-4.8-devpack

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR /solution/workspace

CMD ci
