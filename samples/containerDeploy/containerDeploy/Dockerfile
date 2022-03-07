# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Copy solution, provision and then build
WORKDIR /solution

# Copy Bootstrap Dependancies
COPY automation/provisioning/runner.bat automation/provisioning/runner.bat
COPY automation/provisioning/base.ps1 automation/provisioning/base.ps1
COPY automation/provisioning/installApacheMaven.ps1 automation/provisioning/installApacheMaven.ps1
COPY automation/remote/capabilities.ps1 automation/remote/capabilities.ps1

# Provision Build Dependancies, configure Maven cache to use host user profile volume mount
COPY bootstrapJDK.ps1 .
COPY settings.xml .
RUN automation\provisioning\runner.bat bootstrapJDK.ps1 anypoint-cli

COPY deploy.zip .
RUN powershell -Command Expand-Archive deploy.zip
COPY properties/* /solution/deploy/

# Unlike containerBuild the workspace is not volume mounted, this replicates what the remote deploy process does leaving the image ready to run
WORKDIR /solution/deploy
CMD ["./deploy.ps1", "${ENVIRONMENT}"]
