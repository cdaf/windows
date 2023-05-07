# escape=`
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

# Create root, i.e. C:\solution
WORKDIR /solution

# Shared bootstrap between Docker and Vagrant
COPY provision.ps1 .
RUN powershell -NoProfile -Command ./provision.ps1

# Normal containers run a console application, this is just keeps the container from stopping 
CMD powershell -NoProfile -NonInteractive -command %cd%\provision.ps1 keepalive
