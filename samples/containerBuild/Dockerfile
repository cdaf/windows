# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG proxy
ENV http_proxy=$proxy

# Working directory should be absolute path
WORKDIR /solution

# Provision Build Dependancies
COPY automation-solution/bootstrapAgent.ps1 .
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
RUN .\bootstrapAgent.ps1

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR /solution/workspace

CMD ci
