# Diagnostic CI only. Inject with CMAKE_PROJECT_INCLUDE; no global flag replacement.
include_guard(GLOBAL)

function(bambu_configure_fff_diagnostic_symbols)
    set(_symbols "${CMAKE_BINARY_DIR}/fff-diagnostic-symbols")
    file(MAKE_DIRECTORY "${_symbols}")
    set(_required libslic3r support_material_on_wipe_tower_tests periodic_modifier_tests)
    foreach(_target IN LISTS _required)
        if(NOT TARGET "${_target}")
            message(FATAL_ERROR "FFF diagnostic target missing: ${_target}")
        endif()
        # Language/compiler/configuration guards keep CUDA and other configurations intact.
        target_compile_options("${_target}" PRIVATE
            "$<$<AND:$<CONFIG:Release>,$<COMPILE_LANG_AND_ID:CXX,MSVC>>:/Zi>"
            "$<$<AND:$<CONFIG:Release>,$<COMPILE_LANG_AND_ID:CXX,MSVC>>:/FS>")
        if(MSVC)
            set_target_properties("${_target}" PROPERTIES
                COMPILE_PDB_NAME_RELEASE "${_target}-compile"
                COMPILE_PDB_OUTPUT_DIRECTORY_RELEASE "${_symbols}")
        endif()
    endforeach()
    foreach(_target IN ITEMS support_material_on_wipe_tower_tests periodic_modifier_tests)
        target_link_options("${_target}" PRIVATE
            "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:MSVC>>:/DEBUG:FULL>"
            "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:MSVC>>:/MAP:${_symbols}/${_target}.map>"
            "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:MSVC>>:/OPT:REF>"
            "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:MSVC>>:/OPT:ICF>"
            "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:MSVC>>:/PDBPAGESIZE:8192>")
        if(MSVC)
            set_target_properties("${_target}" PROPERTIES
                PDB_NAME_RELEASE "${_target}"
                PDB_OUTPUT_DIRECTORY_RELEASE "${_symbols}")
        endif()
    endforeach()
    # Portable CMake smoke can verify the deferred mechanism without claiming MSVC execution.
    if(MSVC)
        set(_msvc true)
    else()
        set(_msvc false)
    endif()
    file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/fff-diagnostic-targets-$<CONFIG>.json" CONTENT
"{\n  \"msvc\": ${_msvc},\n  \"compiler\": \"${CMAKE_CXX_COMPILER_ID}\",\n  \"compiler_version\": \"${CMAKE_CXX_COMPILER_VERSION}\",\n  \"configuration\": \"$<CONFIG>\",\n  \"symbol_directory\": \"${_symbols}\",\n  \"core_library\": \"$<TARGET_FILE:libslic3r>\",\n  \"support_executable\": \"$<TARGET_FILE:support_material_on_wipe_tower_tests>\",\n  \"periodic_executable\": \"$<TARGET_FILE:periodic_modifier_tests>\"\n}\n")
endfunction()

# project() includes this file before add_subdirectory declares the actual targets.
cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL bambu_configure_fff_diagnostic_symbols)
