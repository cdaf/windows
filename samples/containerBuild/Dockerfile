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

# < Place cache building here, not in the workspace root or the mount will fail due to non-empty directory >
# COPY tests/pom.xml .
# RUN mvn --batch-mode clean dependency:resolve dependency:go-offline eclipse:eclipse

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR /solution/workspace

CMD ci
