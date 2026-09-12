
param(
    [string]$Release = 'DEV',
    # Skip ci.bat and just load .env and run release.ps1 (use this when the build was run outside VS Code).
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot
try {
    if (-not $SkipBuild) {
        $ciCommand = Get-Command ci.bat -ErrorAction Stop
        & $ciCommand.Source
        $ciExitCode = $LASTEXITCODE
        if ($ciExitCode -ne 0) {
            throw "ci.bat failed with exit code $ciExitCode. Release was not started."
        }
    }

    Get-Content .env | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
    $powershell = Get-Command powershell.exe -ErrorAction Stop
    & $powershell.Source -NoProfile -File (Join-Path $PSScriptRoot 'release.ps1') $Release
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
