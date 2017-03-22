Continuous Delivery Automation Framework (CDAF)
===============================================

    Author  : Jules Clements
    Version : See CDAF.windows

Framework Overview
==================

The automation framework provides a "lowest common denominator" approach, where underlying action are implemented in PowerShell.

This automation framework functionality is based on user defined solution files. By default the /solution folder stores these files, however, a stand alone folder, in the solution root is supported, identified by the CDAF.solution file in the root.

Provisioning
============

When using for the first time, the users workstation needs to be prepared by provisioning the following features

- Package Compression
- Loopback Connection
- Landing Folder

Solution Driver
===============

The following files control solution level functionality.

    CDAF.linux : used by the CD emulator to determine the automation root directory  
    CDAF.solution : optional file to identify a directory as the automation solution directory

Properties and definition files support comments, prefixed with # character.

Execution Engine
----------------
To alleviate the burden of argument passing, exception handling and logging, the execution engine has been provided. The execution engine will essentially execute the native interpretive language (PowerShell or bash), line by line, but each execution will be tested for exceptions (trivial in bash, significantly more complex in PowerShell) and, with careful usage, the driver files (.tsk) can be used on Windows workstations, while target Linux servers for Continuous Delivery. To provide translated runtime, the following keywords are supported

| Keyword | Description                       | Example                    |
| --------|-----------------------------------|---------------------------------|
| ASSIGN  | set a variable                    | ASSIGN $test="Hello World"      |
| CMPRSS  | Compress directory to file        | CMPRSS packageName dirName      |
| DCMPRS  | Decompress package file           | DCMPRS packageName              |
| DECRYP  | decrypt matching target file      | DECRYP cryptLocal               |
|         | decrypt specific file             | DECRYP cryptLocal encrypt.dat   |
| DETOKN  | Detokenise file with target prop  | DETOKN tokenised.file           |
|         | Detokenise with specific file     | DETOKN tokenised.file prop.file |
| EXCREM  | Execute Remote Command            | EXCREM hostname                 |
|         | Execute Remote script             | EXCREM ./capabilities.sh        |
| EXITIF  | Exit normally is argument set     | EXITIF $ACTION                  |
| INVOKE  | call a custom script              | INVOKE ./script "Hello"         |
| MAKDIR  | Create a directory and path (opt) | MAKDIR directory/and/path       |
| PROPLD  | Load properties as variables      | PROPLD prop.file                |
| REMOVE  | Delete files, including wildcard  | REMOVE *.war                    |
| REPLAC  | Replace token in file   		  | REPLAC fileName %token% $value  |
| VECOPY  | Verbose copy					  | VECOPY *.war                    |

Notes on EXCREM use, the properties are similar to those used for remote tasks, where the minimum requried is the host, if other properties are not used, must be set to NOT_SUPPLIED, i.e.

  deployHost=localhost
  remUser=NOT_SUPPLIED
  remCred=NOT_SUPPLIED
  remThb=NOT_SUPPLIED

Runtime variables, automatically set

| Variable         | Description                       |
| -----------------|-----------------------------------|
|  $TMPDIR         | Automatically set to the temp dir |

Build and Package (once)
------------------------

buildProjects: (optional, all directories containing build.ps1 or build.tsk will be processed). The build sequence can be controlled using the optional file, buildProjects. Note: build projects entries needs to be the directory name and not the project name.

Linear Deploy requires properties file for workstation (default is DEV) to be a match (not partial match as per repeatable deploy). Transform.ps1 utility can be used to load all defined properties.

Package: (files maybe empty or non-existent)

	package.tsk : optional pre-package tasks definition
	wrap.tsk : optional post-package tasks definition (0.8.2)
	storeForLocal
	storeForRemote

The package (.zip) file is generated from the contents of the TasksRemote directory, all scripts contained in the /remote folder are copied and files file/directories listed in storeForRemote (maybe empty).

All scripts contained in the /local folder are copied to the TasksLocal directory, along with the files/directories listed in storeForLocal file (maybe empty). A package file of local tasks can also be created by setting zipLocal in the CDAF.solution file, the value set will be used in the package name itself.

Deploy (many)
--------------
Default task definitions, these can be overridden using deployScriptOverride or deployTaskOverride in properties file

	tasksRunLocal.tsk
	tasksRunRemote.tsk

For an empty solution, the automation/cdEmulate.sh should run successfully and simply create a zip file with the remote deployment wrapper and helper scripts. Transform.ps1 utility can be used to load all defined properties or detokenise a settings file.

Optional sub-directories of /solution

	/propertiesForLocalTasks
	/propertiesForRemoteTasks	required properties are deployLand and deployHost (value containing : will be treated as URI)

Encrypted files (for passwords)

	/cryptRemoteRemote
	/cryptRemoteLocal

Custom elements, i,.e. deployScriptOverride and deployTaskOverride scripts

	/customRemote
	/customLocal

Continuous Delivery Emulation
=============================

To support Continuous Delivery, the automation of Deployment is required, to automate deployment, the automation of packaging is required, and to automate packaging, the automation of build is required.

Automated Build
---------------

If it exists, each project in the Project.list file is processed, in order (to support cross project dependencies), if the file does not exist, all project directores are processed, alphabetically.
Each project directory is entered and the build.sh script is executed. Each build script is expected to support build and clean actions.

Automated Packaging
-------------------

The artifacts from each project are copied to the root workspace, along with local and remote support scripts. The remote support scripts and include with the build artifacts in a single zip file, while the local scripts and retained in a directory (DeployLocal). It is the package.sh script which manages this, leaving only artifacts that are to be retained in the workspace root.

Remote Tasks
------------

The automation of deployment uses remote PowerShell to establish a connection to each target in the local/properties files for the environment symbol, i.e. CD, ST, etc. The zip file (Package) is copied to the target host and extracted, the properties file for that target is also copied and then the entry script (deploy.bat) is called.

Local Tasks
-----------

Executed from the current host, i.e. the build server or agent, and may connect to remove hosts through direct protocols, i.e. WebDAV, ODBC/JDBC, HTTP(S), etc.

Frequently Asked Questions
==========================

Why use CDAF
------------

To provide a consistent approach to Continuous Delivery and leverage the efforts of others to provide greater reusability and easier problem determination. CDAF will provide the building blocks for common tasks, with rich logging and exeception handling. The CDAf provides toolset configuration guidance, keeping the actions loosely coupled with the toolset, to allow visibilty and traceability through source control rather than direct changes.

Why not have a shared folder for CDAF on the system
---------------------------------------------------

CDAF principles are to have a minimum level of system dependency. By having solution specific copies each solution can use differing versions of CDAF, and once a solution is upgraded, that upgrade will be propogated to all uses (at next update/pull/get) where a system provisioned solution will requrie all users to update to the same version, even if their current solution has not been tested for this system wide change.