# Container Build

This example highlights how a self-hosted build server can use containers to perform isolated builds. This method supports mutually exclusive requirements such as .NET, Java or NodeJS.

This also enables the developer to codify their build dependencies, via the provisioning script (bootstrapAgent.ps1).

## Image Build

An image is built each time CDAF is run and tagged with build number, the previous version(s) are deleted.

## Container Run

A container is instantiated from the image, with two volume mounts, one for the workspace and another for the user home. The user home mount allows for persisting data between builds, such as Maven cache or dotnet packages.
