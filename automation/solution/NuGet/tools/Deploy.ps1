function throwErrorlevel ($trappedExit) {
    write-host "[$scriptName] Trapped DOS exit code $trappedExit, throwing as exception" -ForegroundColor Red
	write-host
    throw "DOS $trappedExit"
}

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "Deploy.ps1"

# Retreive the current environment
$ENV = $OctopusParameters['Octopus.Environment.Name']
write-host "[$scriptName] ENV     = $ENV"

$VERSION = $OctopusParameters['Octopus.Action[Deploy to IIB].Package.NuGetPackageVersion']
write-host "[$scriptName] VERSION = $VERSION"

$TARGET = $OctopusParameters['Octopus.Environment.Name'] + "_"  + $OctopusParameters['Octopus.Machine.Hostname']
write-host "[$scriptName] TARGET  = $TARGET"

# Extract all available zip files
& 7za.exe x *.zip

# list what we have to work with
dir 

# cd $WORKSPACE
# write-host
# & .\deploy.bat $TARGET $ENVIRONMENT
# if(!$?){ throwErrorlevel $LASTEXITCODE }