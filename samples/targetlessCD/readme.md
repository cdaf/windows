# Targetless CD

> Can only be executed on Windows Server 2022 or Windows 11

Execute function test without deploying a target, instead, perform test in docker-compose environment.

This leverages two key featues of imageBuild

## Post Build & Package Image Build

Triggered from the CDAF.solution property

    buildImage=docker.io/library/python:latest

This launches the default construction process. After the Build and Package is complete, the customer Dockerfile is placed in Taskslocal, this is used to construct the deliverable image.

## Build All Images

At deploy time, the `compose.tsk` calls imageBuild without specifying an image or constructor, this triggers a build of each subdirectory

### Default Image

A base image is not supplied, so `dockerBuild` will attempt to derive from the `runtimeImage` property.
