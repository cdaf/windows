# escape=`
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Create root, i.e. C:\solution
WORKDIR /solution

# Shared bootstrap between Docker and Vagrant
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
RUN curl.exe -fsO "https://raw.githubusercontent.com/cdaf/windows/refs/heads/master/provisioning/base.ps1"
RUN ./base.ps1 netfx-4.8-devpack

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR /solution/workspace

# Normal containers run a console application, this is just keeps the container from stopping 
CMD ["Wait-Event"]
