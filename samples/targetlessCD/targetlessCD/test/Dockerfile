# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

MAINTAINER Jules Clements

ARG proxy
ENV http_proxy=$proxy

# Create root, i.e. C:\solution
WORKDIR solution

# Copy CDAF from solution (avoid bootStrap downloading)
COPY automation automation

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTarget.ps1 .
RUN automation\provisioning\runner.bat bootstrapTarget.ps1

# Change workdir to an new (empty) folder for volume mount to work
WORKDIR workspace

# Unlike the web server, this container is transient, and does not build the wrapper into the image, instead this relies of the volume mount
CMD ["C:/solution/automation/provisioning/runner.bat", "executeTests.ps1", "http://web", "'IIS Windows Server'"]