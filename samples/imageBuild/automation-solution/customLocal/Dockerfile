# escape=`
ARG CONTAINER_IMAGE
FROM ${CONTAINER_IMAGE}

EXPOSE 80

ARG HTTP_PROXY
ENV HTTP_PROXY=$HTTP_PROXY

# Create root, i.e. C:\solution
WORKDIR /solution

# Alternative is to filter scripts in storeForLocal and just copy automation directory, see compose.tsk
COPY base.ps1 ./automation/provisioning/base.ps1
COPY capabilities.ps1 ./automation/remote/capabilities.ps1

# Shared bootstrap between Docker and Vagrant
COPY bootstrapTarget.ps1 .
RUN powershell -NoProfile -Command ./bootstrapTarget.ps1

# Replace default content
RUN powershell -NoProfile -Command Remove-Item -Recurse C:\inetpub\wwwroot\*
ADD content.tar.gz /inetpub/wwwroot/

# Normal containers run a console application, this example works in a more similar way to a traditional daemon server
# CMD ["dotnet", "app.dll"]
