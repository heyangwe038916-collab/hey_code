$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ProjectRoot "dist\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "daily_mail_$Timestamp.log"
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

if (Test-Path $VenvPython) {
    $Python = $VenvPython
} else {
    $Python = "python"
}

Set-Location $ProjectRoot
& $Python -m src.send_mail --attach-json *> $LogFile
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
    Get-Content $LogFile
    exit $ExitCode
}

Get-Content $LogFile
