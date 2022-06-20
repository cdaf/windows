# escape=`
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

ARG HTTP_PROXY
ENV HTTP_PROXY=$HTTP_PROXY

# Create root, i.e. C:\solution
WORKDIR /solution

# Shared bootstrap between Docker and Vagrant
COPY provision.ps1 .
RUN powershell -NoProfile -Command ./provision.ps1

# Normal containers run a console application, this example works in a more similar way to a traditional daemon server
# CMD ["TIMEOUT", "-1"]
