# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Create root, i.e. C:\solution
WORKDIR /solution

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTarget.ps1 .
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
RUN ./bootstrapTarget.ps1

# Change workdir to an new (empty) folder for volume mount to work
WORKDIR /solution/workspace
