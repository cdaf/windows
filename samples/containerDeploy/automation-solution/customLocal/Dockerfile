# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

MAINTAINER Jules Clements

ARG proxy
ENV http_proxy=$proxy

# Copy solution, provision and then build
WORKDIR solution

# Provision Build Dependancies
COPY automation/provisioning/base.ps1 automation/provisioning/base.ps1
COPY automation/remote/capabilities.ps1 automation/remote/capabilities.ps1
COPY automation/provisioning/runner.bat .
COPY compose/target/bootstrapTarget.ps1 .
RUN runner.bat bootstrapTarget.ps1 -deploy yes

# < Place cache building here, not in the workspace root or the mount will fail due to non-empty directory >
COPY FunctionApp/pom.xml .
RUN mvn --batch-mode clean dependency:resolve dependency:go-offline eclipse:eclipse

# Change workdir to the mapped folder so that the build artefacts are available on the host
WORKDIR workspace

CMD [ "..\runner.bat", ".\delivery.ps1", "$env:MAVEN_DEPLOY_TARGET", "release", "deploy", "." ]
