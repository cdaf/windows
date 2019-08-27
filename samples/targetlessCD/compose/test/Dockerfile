# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

MAINTAINER Jules Clements

ARG proxy
ENV http_proxy=$proxy

ARG CP_COMPOSE_KEEP
ENV CP_COMPOSE_KEEP=$CP_COMPOSE_KEEP

# Create root, i.e. C:\solution
WORKDIR solution

# Copy entire directory (rely on storeForLocal to limit to only to required, unlike containerBuild)
COPY automation automation

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTest.ps1 .
RUN automation\provisioning\runner.bat bootstrapTest.ps1

# Place entry script
COPY executeTest.ps1 .

# Change workdir to an new (empty) folder for volume mount to work
WORKDIR workspace

# Unlike the web server, this container is transient, and does not build the wrapper into the image, instead this relies of the volume mount
CMD ["C:/solution/automation/provisioning/runner.bat", "../executeTest.ps1", "AUTO_TEST"]