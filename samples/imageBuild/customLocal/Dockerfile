# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG proxy
ENV http_proxy=$proxy

# Create root, i.e. C:\solution
WORKDIR /solution

# Copy entire directory (rely on storeForLocal to limit to only to required, unlike containerBuild)
COPY automation automation

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTarget.ps1 .
RUN automation\provisioning\runner.bat bootstrapTarget.ps1

# Place entry script
COPY keepAlive.ps1 .

# Start the application
EXPOSE 5000
CMD ["start.ps1"]