# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG proxy
ENV http_proxy=$proxy

# Copy solution, provision and then build
WORKDIR C:\\solution

# Provision Build Dependancies
COPY automation/provisioning/base.ps1 automation/provisioning/base.ps1
COPY automation/remote/capabilities.ps1 automation/remote/capabilities.ps1
COPY automation-solution/bootstrapAgent.ps1 .
COPY automation/provisioning/runner.bat .
RUN runner.bat bootstrapAgent.ps1

# < Place cache building here, not in the workspace root or the mount will fail due to non-empty directory >
# COPY tests/pom.xml .
# RUN mvn --batch-mode clean dependency:resolve dependency:go-offline eclipse:eclipse

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR C:\\solution\\workspace

CMD echo Usage: docker run --tty --volume ${workspace}\:C:/solution/workspace ${imageName}:${imageTag} automation\ci.bat $buildNumber revision containerbuild
