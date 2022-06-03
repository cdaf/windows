# Continuous Delivery Automation Framework (CDAF)

    Author  : Jules Clements
    Version : See CDAF.windows

This readme focuses on implementation details of the framework, see the overview documentation, see http://cdaf.io/about

# Provisioning

When using for the first time, the users workstation needs to be prepared by provisioning the following features

- Package Compression
- Loopback Connection
- Landing Folder

# Solution Driver

See [Solution Properties](https://docs.cdaf.io/mydoc_solution_properties.html)

Basic driver files (introduced 1.7.8):

	properties.cm
	storeFor
	tasksRun.tsk

Properties and definition files support comments, prefixed with # character.

## Execution Engine

See [Execution Engine is docs](https://docs.cdaf.io/mydoc_basics_execution_engine.html)

## Build and Package (once)

buildProjects: (optional, all directories containing build.ps1 or build.tsk will be processed). The build sequence can be controlled using the optional file, buildProjects. Note: build projects entries needs to be the directory name and not the project name.

	prebuild.tsk : optional pre-build tasks definition (2.4.4)
	postbuild.tsk : optional pre-build tasks definition (2.4.4)

Linear Deploy requires properties file for workstation (default is DEV) to be a match (not partial match as per repeatable deploy). Transform.ps1 utility can be used to load all defined properties.

Package: (files maybe empty or non-existent)

	package.tsk : optional pre-package tasks definition (0.7.2)
	wrap.tsk : optional post-package tasks definition (0.8.2)
	storeForLocal
	storeForRemote

The package (.zip) file is generated from the contents of the TasksRemote directory, all scripts contained in the /remote folder are copied and files file/directories listed in storeForRemote (maybe empty).

All scripts contained in the /local folder are copied to the TasksLocal directory, along with the files/directories listed in storeForLocal file (maybe empty). A package file of local tasks can also be created by setting zipLocal in the CDAF.solution file, the value set will be used in the package name itself.

## Deploy (many)

Default task definitions, these can be overridden using deployScriptOverride or deployTaskOverride (a space separated list is supported) in properties file

	tasksRunLocal.tsk
	tasksRunRemote.tsk

For an empty solution, the automation/cdEmulate.bat should run successfully and simply create a zip file with the remote deployment wrapper and helper scripts. Transform.ps1 utility can be used to load all defined properties or detokenise a settings file.

Optional sub-directories of /solution

	/propertiesForLocalTasks
	/propertiesForRemoteTasks	required properties are deployLand and deployHost (value containing : will be treated as URI)

Encrypted files (for passwords), see automation/provisioning/crypt.ps1 to create encrypted password files

	/cryptRemoteRemote
	/cryptRemoteLocal

Custom elements, i.e. deployScriptOverride and deployTaskOverride scripts

	/custom
	/customRemote
	/customLocal

## Common Functions

VARCHK varlistFileName example file

    # Plain text values
    OPT_ARG                                         # Optional plain text
    terraform_version=required                      # Required plain text

    # Secret values
    env:TERRAFORM_TOKEN=optional                    # Optional secret
    env:TERRAFORM_TOKEN=secret                      # Required secret
    env:TERRAFORM_TOKEN=$env:TERRAFORM_TOKEN_MASKED # Required secret verified against supplied MASKED value

# Continuous Delivery Emulation

To support Continuous Delivery, the automation of Deployment is required, to automate deployment, the automation of packaging is required, and to automate packaging, the automation of build is required.

## Build and Package  

To produce a self-extracting shell script for deployment, set artifactPrefix in CDAF.solution

### Automated Build

If it exists, each project in the Project.list file is processed, in order (to support cross project dependencies), if the file does not exist, all project directories are processed, alphabetically.
Each project directory is entered and the build.ps1 script is executed. Each build script is expected to support build and clean actions.

### Automated Packaging

The artifacts from each project are copied to the root workspace, along with local and remote support scripts. The remote support scripts and include with the build artifacts in a single zip file, while the local scripts and retained in a directory (DeployLocal). It is the package.ps1 script which manages this, leaving only artifacts that are to be retained in the workspace root.

## Container Builds

This functionality allows for multiple build requirements (which maybe mutually exclusive at a system level) to be combined on a single host. It is expected that the build dependencies are defined in code (bootstrapAgent.ps1) and not image based. This exploits the disk layer mechanisms of Docker to only rebuild the agent image if a change in definition occurs and not every time a build is perform.

### Applying a Container Build

 - Copy the Dockerfile from the GitHub samples directory to the root of your solution
 - Copy the bootstrapAgent.ps1 from the GitHub samples to your solution folder
 - uncomment the containerBuild line from the CDAF.solution in your solution folder

Alter the bootstrapAgent.ps1 to fulfill the build dependencies. Note: if you have a Vagrantfile for your solution, ideally the same bootstrap would be used for both Vagrant and Container Build implementations:

    override.vm.provision 'shell', path: './automation-solution/bootstrapAgent.ps1'

## Remote Tasks

The automation of deployment uses remote PowerShell to establish a connection to each target in the local/properties files for the environment symbol, i.e. CD, ST, etc. The zip file (Package) is copied to the target host and extracted, the properties file for that target is also copied and then the entry script (deploy.bat) is called.

## Local Tasks

Executed from the current host, i.e. the build server or agent, and may connect to remove hosts through direct protocols, i.e. WebDAV, ODBC/JDBC, HTTP(S), etc.

## Feature Branch Environments

Only available when using Git aware entry.ps1. If file feature-branch.properties is found in solution root, each matching branch name prefix will be deployed to the defined environment in the CI process. Example contents

    # Separate environments for features and bugs
    feature=DEV1
    bugfix=DEV2

    # Hotfixes deploy to all environments
    hotfix=DEV1
    hotfix=DEV2
