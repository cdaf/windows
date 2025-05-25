# DOCKER-VERSION 1.2.0
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Create root, i.e. C:\solution
WORKDIR /solution

# Place entry script
COPY executeTest.ps1 .

# Change workdir to an new (empty) folder for volume mount to work
WORKDIR /solution/workspace

# Unlike the web server, this container is transient, and does not build the wrapper into the image, instead this relies of the volume mount
CMD ["powershell", "-Command", "../executeTest.ps1", "AUTO_TEST"]