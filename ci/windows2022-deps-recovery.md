# Bambu VS2022 dependency recovery

Build exact tracked dependency tree dfcee1c78f98fa9ada89f461a2f4653ec9ad4cca from source floor c43bc49004a6ce527887056bfb4b31c0b6494dc8. Dedicated fork branch ci/windows2022-deps-2.9.1 builds dependencies only with CMake 3.31.6, VS17/v143 x64 Release and DEP_DEBUG=OFF. DESTDIR is deps/build/BambuStudio_dep; build directory is build-deps. No dependency-source or application code changes.

The successful SMB job 127110665463 from run 41987086087 used VS18 2026 / MSVC19.51, while failed GPU job127189555530 used VS17 2022 / MSVC19.44. The upstream archive naming _vs2022 does not prove its compiler version. The unresolved STL functions require rebuilding these static libraries with the selected app toolchain.

Completed artifact Bambu-2.9.1-Windows2022-v143-deps contains a ZIP with usr/local at its root, SHA256SUMS.txt, Bambu-dependency-source.txt, tracked dependency manifest, compiler version, CMake cache/compiler metadata and MSBuild version. Full configure/build logs are uploaded separately even on failure. Consumer must verify source/tree/compiler and archive digest before extraction into deps/build/BambuStudio_dep. No app build runs in this producer.

Local readiness: YAML parsed and all six PowerShell run blocks parsed by PowerShell AST. Actual dependency compilation is pending the published native runner; no local native-build pass is claimed.

## Actual successful SMB compiler evidence

```
2026-11-05T07:28:03.3850522Z [36;1mcmake -S . -B build -G 'Visual Studio 18 2026' -A X64 -DBBL_RELEASE_TO_PUBLIC=1 -DBBL_INTERNAL_TESTING=0 "-DCMAKE_PREFIX_PATH=$pwd/deps/build/BambuStudio_dep/usr/local" "-DCMAKE_INSTALL_PREFIX=$pwd/install-dir" -DCMAKE_BUILD_TYPE=Release "-DWIN10SDK_PATH=$sdk"[0m
2026-11-05T07:28:13.8486672Z -- The C compiler identification is MSVC 19.51.36260.0
2026-11-05T07:28:15.2398897Z -- The CXX compiler identification is MSVC 19.51.36260.0
2026-11-05T07:28:16.4007060Z -- Check for working C compiler: C:/Program Files/Microsoft Visual Studio/18/Enterprise/VC/Tools/MSVC/14.51.36231/bin/Hostx64/x64/cl.exe - skipped
2026-11-05T07:28:17.1940506Z -- Check for working CXX compiler: C:/Program Files/Microsoft Visual Studio/18/Enterprise/VC/Tools/MSVC/14.51.36231/bin/Hostx64/x64/cl.exe - skipped
2026-11-05T07:28:24.5372922Z -- Targetting Visual Studio 18 2026
2026-11-05T07:29:14.5003751Z -- [download 25% complete]
2026-11-05T07:29:14.5032363Z -- [download 26% complete]
2026-11-05T07:29:14.5043077Z -- [download 27% complete]
2026-11-05T07:29:14.5057604Z -- [download 28% complete]
2026-11-05T07:29:14.5066928Z -- [download 29% complete]
2026-11-05T07:29:14.5077205Z -- [download 30% complete]
2026-11-05T07:29:14.5086779Z -- [download 31% complete]
2026-11-05T07:29:14.5099171Z -- [download 32% complete]
2026-11-05T07:29:14.5112639Z -- [download 33% complete]
2026-11-05T07:29:14.5123075Z -- [download 34% complete]
2026-11-05T07:29:14.5134936Z -- [download 35% complete]
2026-11-05T07:29:14.5145715Z -- [download 36% complete]
2026-11-05T07:29:14.5156317Z -- [download 37% complete]
2026-11-05T07:29:14.5167048Z -- [download 38% complete]
2026-11-05T07:29:14.5223783Z -- [download 39% complete]
2026-11-05T07:29:14.5242915Z -- [download 40% complete]
2026-11-05T07:29:14.5257463Z -- [download 41% complete]
2026-11-05T07:29:14.5267700Z -- [download 42% complete]
2026-11-05T07:29:14.5278038Z -- [download 43% complete]
```
