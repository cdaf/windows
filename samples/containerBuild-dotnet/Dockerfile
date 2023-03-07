# escape=`

ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

WORKDIR C:\\solution

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
COPY bootstrap.ps1 .
RUN ./bootstrap.ps1

# Run container in empty directory, i.e. suitable for volume mounting
WORKDIR C:\\solution\\workspace

CMD ci
