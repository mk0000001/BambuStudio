function Test-DiagnosticMsvcVersion {
  param([string]$Version)
  return $Version -match '^19\.(3[0-9]|4[0-9])\.[0-9]+(\.[0-9]+)?$'
}

function Invoke-FffDiagnosticProcess {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [string[]]$Arguments = @('[gcode_output_path]'),
    [ValidateRange(100,180000)][int]$WatchdogMilliseconds = 180000
  )
  $ErrorActionPreference = 'Stop'
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  $record = [ordered]@{schema=1; name=$Name; source=$Source; executable=$Executable; executable_sha256=$null; arguments=$Arguments; backend='cpu'; working_directory=$WorkingDirectory; watchdog_ms=$WatchdogMilliseconds; started=$false; exited=$false; timed_out=$false; streams_complete=$false; exit_code_signed32=$null; exit_code_unsigned_hex=$null; collection_error=$null; status='DIAGNOSTIC_COLLECTION_ONLY_NOT_A_TEST_PASS'}
  $process = [System.Diagnostics.Process]::new()
  try {
    $record.executable_sha256 = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash.ToLowerInvariant()
    $process.StartInfo.FileName = $Executable
    $process.StartInfo.WorkingDirectory = $WorkingDirectory
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$process.StartInfo.ArgumentList.Add($argument) }
    $process.StartInfo.Environment['SLIC3R_GPU_BACKEND'] = 'cpu'
    $process.StartInfo.Environment['PATH'] = "$RuntimeDirectory;$env:PATH"
    $record.started = $process.Start()
    if (-not $record.started) { throw 'Owned diagnostic child did not start' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $record.exited = $process.WaitForExit($WatchdogMilliseconds)
    if (-not $record.exited) {
      $record.timed_out = $true
      $process.Kill($true)
      $record.exited = $process.WaitForExit(10000)
    }
    if ($record.exited) {
      $record.exit_code_signed32 = [int32]$process.ExitCode
      $unsigned = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$process.ExitCode), 0)
      $record.exit_code_unsigned_hex = '0x{0:X8}' -f $unsigned
    }
    $record.streams_complete = [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($stdout,$stderr),10000)
    if ($stdout.IsCompletedSuccessfully) { [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Name.stdout.log"),$stdout.Result) }
    if ($stderr.IsCompletedSuccessfully) { [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Name.stderr.log"),$stderr.Result) }
  } catch {
    $record.collection_error = $_.Exception.Message
  } finally {
    if ($record.started -and -not $record.exited) {
      try { if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(10000) } } catch { $record.collection_error = "Owned child cleanup failed: $($_.Exception.Message)" }
    }
    $process.Dispose()
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory "$Name.exit.json") -Encoding utf8
  }
  return [pscustomobject]$record
}

if ($MyInvocation.InvocationName -ne '.') {
  # Collection failures/nonzero child exits are evidence, not a replacement test gate.
  # The unchanged full10 CTest step must execute after this collector.
  $ErrorActionPreference = 'Stop'
  $directory = Join-Path $pwd 'fff-native-phase-evidence'
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
  try {
    $source = (git rev-parse HEAD).Trim()
    $metadata = Get-Content build-gpu/fff-diagnostic-targets-Release.json -Raw | ConvertFrom-Json
    foreach ($executable in @($metadata.support_executable,$metadata.periodic_executable)) {
      $name = [IO.Path]::GetFileNameWithoutExtension($executable)
      $record = Invoke-FffDiagnosticProcess -Name $name -Executable $executable -WorkingDirectory ([IO.Path]::GetDirectoryName($executable) | Split-Path -Parent) -OutputDirectory $directory -Source $source -RuntimeDirectory (Join-Path $pwd 'install-beta')
      Write-Host "$name diagnostic exited=$($record.exited) timeout=$($record.timed_out) signed32=$($record.exit_code_signed32) hex=$($record.exit_code_unsigned_hex) error=$($record.collection_error)"
    }
  } catch {
    [ordered]@{status='DIAGNOSTIC_SETUP_FAILED_FULL_CTEST_STILL_REQUIRED'; error=$_.Exception.Message} | ConvertTo-Json | Set-Content "$directory/collection-error.json" -Encoding utf8
  }
  # Never reinterpret the child's failure as success. Its actual exit record is retained;
  # this collector itself succeeds so the original, unchanged CTest gate is not skipped.
  exit 0
}
