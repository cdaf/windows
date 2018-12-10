# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG proxy
ENV http_proxy=$proxy

# Copy solution, provision and then build
WORKDIR solution

# Provision Build Dependancies
COPY automation-solution/bootstrapAgent.ps1 .
COPY automation/provisioning/runner.bat .
RUN runner.bat bootstrapAgent.ps1

# Copy the project POM into solution root to build cache, not in the workspace root or the mount will fail
COPY tests/pom.xml .
RUN mvn --batch-mode clean install

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR workspace

CMD echo Usage: docker run --tty --volume ${workspace}\:C:/solution/workspace ${imageName}:${imageTag} automation\processor\buildPackage.bat $buildNumber revision containerbuild
