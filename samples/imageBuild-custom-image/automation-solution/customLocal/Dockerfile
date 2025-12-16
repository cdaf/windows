# escape=`
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Shared bootstrap between Docker and Vagrant
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
RUN base.ps1 netfx-4.8-devpack

# If not using the CDAF base image
# RUN curl.exe -fsO "https://raw.githubusercontent.com/cdaf/windows/refs/heads/master/provisioning/base.ps1"
# RUN ./base.ps1 netfx-4.8-devpack

# Normal containers run a console application, this is just keeps the container from stopping 
CMD ["Wait-Event"]
