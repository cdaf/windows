Continuous Delivery Automation Framework (CDAF)
===============================================

    Author  : Jules Clements
    Date    : 01-May-2015
    Version : 0.8.0

Framework Overview
==================

The automation framework provides a "lowest common denominator" approach, where underlying action are implemented in PowerShell.

This automation framework functionality is based on user defined solution files. By default the /solution folder stores these files, however, a stand alone folder, in the solution root is supported, identified by the CDAF.solution file in the root.

Provisioning
============

When using for the first time, the users workstation needs to be prepared by provisioning the following features

- Loopback Connection
- Landing Folder

Loop-back Connection
--------------------

The loop-back connection is used to emulate a remote host on the current workstation.

The loop-back connection is established using remote PowerShell, to enable this, right-click the EnableServerRemoting.bat in automation\provisioning\remotePowershellProvisioning, select Y for each of the prompts. The current user will be used as the default user when performing a loop-back connection.

Landing Folder
--------------

The landing folder is defined in the properties file (in propertiesForRemoteTasks folder), default "DEV". This folder must exists and the loop-back connection user my have write access to it.

CDAF Verify
-----------

Before implementing any aspects of the solution, run the emulator to verify the provisioning steps. The logs from the emulator run will provide guidance as to what files should be edited to implement continuous delivery, the following documentation provides more details around each key process.

     .\automation\cdEmulate.bat

Driver Files
============

The following files are the solution files that are configured to implement a given solution. There is a single solution level properties files, then sets of files for each key process.

    CDAF.solution : optional file to identify a directory as the automation solution directory

Properties and definition files support comments, prefixed with # character.

Build and Package (once)
------------------------

buildProjects: (optional, all directories containing build.ps1 or build.tsk will be processed). The build sequence can be controlled using the optional file, buildProjects. Note: build projects entries needs to be the directory name and not the project name.

Linear Deploy requires properties file for workstation (default is DEV) to be a match (not partial match as per repeatable deploy). Transform.ps1 utility can be used to load all defined properties.

Package: (files maybe empty or non-existent)

	package.tsk : optional pre-package tasks definition
	storeForLocal
	storeForRemote

The package (.zip) file is generated from the contents of the TasksRemote directory, all scripts contained in the /remote folder are copied and files file/directories listed in storeForRemote (maybe empty).

All scripts contained in the /local folder are copied to the TasksLocal directory, along with the files/directories listed in storeForLocal file (maybe empty).

Execute (many)
--------------
Default task definitions, these can be overridden using deployScriptOverride= in properties file

	tasksRunLocal.tsk
	tasksRunRemote.tsk

For an empty solution, the automation/cdEmulate.sh should run successfully and simply create a zip file with the remote deployment wrapper and helper scripts. Transform.ps1 utility can be used to load all defined properties or detokenise a settings file.

Optional sub-directories of /solution

	/propertiesForLocalTasks
	/propertiesForRemoteTasks	required properties are deployLand and deployHost (value containing : will be treated as URI)

Encrypted files (for passwords)

	/cryptRemoteRemote
	/cryptRemoteLocal

Custom elements, i,.e. deployScriptOverride scripts

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

Automated Function Tests
------------------------

Not yet implemented in .NET/Windows solutions.