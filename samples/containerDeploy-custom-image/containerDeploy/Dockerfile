# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Copy solution, provision and then build
WORKDIR /solution

# Provision Build Dependancies, configure Maven cache to use host user profile volume mount
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
COPY bootstrapAgent.ps1 .
RUN .\bootstrapAgent.ps1 anypoint-cli

COPY properties/* /solution/deploy/
COPY deploy.zip .
RUN powershell -Command Expand-Archive deploy.zip

# Unlike containerBuild the workspace is not volume mounted, this replicates what the remote deploy process does leaving the image ready to run
WORKDIR /solution/deploy
CMD ["./deploy.ps1", "${ENVIRONMENT}"]
