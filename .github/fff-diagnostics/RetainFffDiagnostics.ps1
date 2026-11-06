$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/CaptureFffExit.ps1"
$workspace = (Get-Location).Path
$stage = Join-Path $workspace 'fff-diagnostic-bundle'
if (Test-Path -LiteralPath $stage) { throw 'Diagnostic staging directory must be fresh' }
New-Item -ItemType Directory $stage, "$stage/fff", "$stage/symbols", "$stage/runtime", "$stage/build-metadata" | Out-Null
$metadata = Get-Content build-gpu/fff-diagnostic-targets-Release.json -Raw | ConvertFrom-Json
if (-not $metadata.msvc -or $metadata.compiler -ne 'MSVC' -or -not (Test-DiagnosticMsvcVersion $metadata.compiler_version) -or $metadata.configuration -ne 'Release') { throw 'Wrong actual diagnostic compiler/configuration' }
$targets = @('support_material_on_wipe_tower_tests','periodic_modifier_tests')
$actual = @($metadata.support_executable, $metadata.periodic_executable)
for ($i = 0; $i -lt $targets.Count; $i++) {
  if ([IO.Path]::GetFileName($actual[$i]) -ne "$($targets[$i]).exe" -or -not (Test-Path -LiteralPath $actual[$i] -PathType Leaf)) { throw 'Actual diagnostic executable missing' }
  Copy-Item -LiteralPath $actual[$i] -Destination "$stage/fff"
  foreach ($extension in @('pdb','map')) {
    $symbol = Join-Path $metadata.symbol_directory "$($targets[$i]).$extension"
    if (-not (Test-Path -LiteralPath $symbol -PathType Leaf)) { throw "Required linker symbol missing: $symbol" }
    if ((Get-Item -LiteralPath $symbol).Length -eq 0) { throw 'Empty linker symbol file' }
    Copy-Item -LiteralPath $symbol -Destination "$stage/symbols"
  }
}
foreach ($name in @('libslic3r') + $targets) {
  $pdb = Join-Path $metadata.symbol_directory "$name-compile.pdb"
  if (-not (Test-Path -LiteralPath $pdb -PathType Leaf)) { throw "Required compiler PDB missing: $name" }
  Copy-Item -LiteralPath $pdb -Destination "$stage/symbols"
}
$runtime = @(Get-ChildItem install-beta -File -Filter '*.dll')
if (-not $runtime.Count) { throw 'Matching installed runtime DLLs missing' }
$runtime | Copy-Item -Destination "$stage/runtime"
foreach ($name in @('BambuStudio.dll','cudart64_12.dll','vulkan-1.dll')) {
  if (-not (Test-Path -LiteralPath "$stage/runtime/$name" -PathType Leaf)) { throw "Matching runtime missing: $name" }
}
Copy-Item LICENSE "$stage/LICENSE-AGPL-3.0.txt"
if (-not (Test-Path -LiteralPath 'install-beta/licenses' -PathType Container)) { throw 'Packaged runtime notices missing' }
Copy-Item install-beta/licenses "$stage/licenses" -Recurse
Copy-Item build-gpu/fff-diagnostic-targets-Release.json,build-gpu/CMakeCache.txt,maintained-test-manifest.json,dependency-source-used.txt,dependency-archive-sha256.txt,dependency-compiler-used.cmake -Destination "$stage/build-metadata"
Copy-Item .github/fff-diagnostics/TargetedFffSymbols.cmake,.github/fff-diagnostics/RetainFffDiagnostics.ps1,.github/fff-diagnostics/CaptureFffExit.ps1 -Destination "$stage/build-metadata"
$compiler = @(Get-ChildItem build-gpu/CMakeFiles -Recurse -File -Filter CMakeCXXCompiler.cmake)
if ($compiler.Count -ne 1) { throw 'Actual app compiler metadata ambiguous' }
Copy-Item -LiteralPath $compiler[0].FullName -Destination "$stage/build-metadata/app-CMakeCXXCompiler.cmake"
Copy-Item build-gpu/.cmake/api/v1/reply "$stage/build-metadata/cmake-file-api" -Recurse
foreach ($target in @('libslic3r') + $targets) {
  $project = @(Get-ChildItem build-gpu -Recurse -File -Filter "$target.vcxproj")
  if ($project.Count -ne 1) { throw "Actual project file ambiguous: $target" }
  Copy-Item -LiteralPath $project[0].FullName -Destination "$stage/build-metadata"
}
if (@(git status --porcelain --untracked-files=no).Count) { throw 'Tracked source changed during build' }
$source = (git rev-parse HEAD).Trim()
$tree = (git rev-parse 'HEAD^{tree}').Trim()
git archive --format=tar --output="$stage/source.tar" HEAD
if ($LASTEXITCODE) { exit $LASTEXITCODE }
$identity = [ordered]@{schema=1; status='UNQUALIFIED_DIAGNOSTIC_NOT_RELEASE_PRE_CTEST'; source=$source; tree=$tree; repository=$env:GITHUB_REPOSITORY; run_id=$env:GITHUB_RUN_ID; run_attempt=$env:GITHUB_RUN_ATTEMPT; original_test_cwd='build-gpu/tests/fff_print'; test_executables=$targets; runtime_search_directory='runtime'; native_execution_by_packager=$false; compiler=$metadata.compiler; compiler_version=$metadata.compiler_version; configuration=$metadata.configuration; debug_options='targeted CXX Release /Zi /FS; FFF /DEBUG:FULL /MAP /OPT:REF /OPT:ICF /PDBPAGESIZE:8192; existing /O2 unchanged'}
$identity | ConvertTo-Json -Depth 10 | Set-Content "$stage/IDENTITY.json" -Encoding utf8
'Diagnostic only, not a release. Contains exact built test executables before CTest plus matching compiler/linker symbols, runtime DLLs, tracked source and metadata. Read IDENTITY.json and verify FILE-SHA256.json before any execution. CTest results and phase logs are a separate post-test evidence artifact. This archive makes no FFF, GPU, performance or release success claim.' | Set-Content "$stage/DIAGNOSTIC-NOTICE.txt" -Encoding utf8
$hashes = @()
foreach ($file in @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName)) {
  $relative = [IO.Path]::GetRelativePath($stage, $file.FullName).Replace([char]92,[char]47)
  $hashes += [ordered]@{path=$relative; size=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$hashes | ConvertTo-Json -Depth 10 | Set-Content "$stage/FILE-SHA256.json" -Encoding utf8
$archive = Join-Path $workspace 'UNQUALIFIED-Bambu-FFF-diagnostic-symbols.zip'
tar -a -c -f $archive -C $stage fff symbols runtime licenses build-metadata source.tar LICENSE-AGPL-3.0.txt IDENTITY.json DIAGNOSTIC-NOTICE.txt FILE-SHA256.json
if ($LASTEXITCODE) { exit $LASTEXITCODE }
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  UNQUALIFIED-Bambu-FFF-diagnostic-symbols.zip" | Set-Content fff-diagnostic-sha256.txt -Encoding ascii
$identity | ConvertTo-Json -Depth 10 | Set-Content fff-diagnostic-identity.json -Encoding utf8
Write-Host "Retained $($targets.Count) actual FFF executables and seven mandatory symbol files; archive SHA256=$hash"
