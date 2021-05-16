# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG HTTP_PROXY
ENV HTTP_PROXY=$HTTP_PROXY

# Create root, i.e. C:\solution
WORKDIR /solution

# Alternative is to filter scripts in storeForLocal and just copy automation directory, see compose.tsk
COPY base.ps1 ./automation/provisioning/base.ps1
COPY capabilities.ps1 ./automation/remote/capabilities.ps1

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTest.ps1 .
RUN powershell -NoProfile -Command ./bootstrapTest.ps1

# Place entry script
COPY executeTest.ps1 .

# Change workdir to an new (empty) folder for volume mount to work
WORKDIR /solution/workspace

# Unlike the web server, this container is transient, and does not build the wrapper into the image, instead this relies of the volume mount
CMD ["C:/solution/automation/provisioning/runner.bat", "../executeTest.ps1", "AUTO_TEST"]