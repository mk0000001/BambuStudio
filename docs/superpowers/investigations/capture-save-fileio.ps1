param(
    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,
    [ValidateRange(10, 60)]
    [int] $DurationSeconds = 45
)

$ErrorActionPreference = 'Stop'
$captureDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $captureDirectory -Force | Out-Null
trap {
    ($_ | Out-String) | Set-Content -LiteralPath (Join-Path $captureDirectory 'capture-error.txt')
    exit 1
}
Start-Transcript -LiteralPath (Join-Path $captureDirectory 'capture-log.txt') -Force | Out-Null
$captureIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$capturePrincipal = New-Object Security.Principal.WindowsPrincipal($captureIdentity)
if (-not $capturePrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator elevation is required for the Windows FileIO trace.'
}

# Do not interfere with an existing WPR session.
$initialTraceStatus = (& wpr.exe -status 2>&1 | Out-String)
if ($initialTraceStatus -notmatch 'WPR is not recording') {
    throw 'Another WPR recording may be active; no capture was started.'
}

$captureFile = Join-Path $captureDirectory 'save-fileio.etl'
if (Test-Path -LiteralPath $captureFile) {
    throw 'Capture already exists; choose a new output directory.'
}
$captureStatusFile = Join-Path $captureDirectory 'capture-status.txt'

& wpr.exe -start FileIO -filemode
if ($LASTEXITCODE -ne 0) {
    throw 'WPR refused to start the FileIO trace.'
}
try {
    Set-Content -LiteralPath $captureStatusFile -Value 'recording' -Encoding ascii
    Start-Sleep -Seconds $DurationSeconds
}
finally {
    & wpr.exe -stop $captureFile
    if ($LASTEXITCODE -eq 0) {
        Set-Content -LiteralPath $captureStatusFile -Value 'complete' -Encoding ascii
    }
    else {
        Set-Content -LiteralPath $captureStatusFile -Value 'stop-failed' -Encoding ascii
        throw 'WPR could not save/stop the trace. Check wpr -status before retrying.'
    }
}
