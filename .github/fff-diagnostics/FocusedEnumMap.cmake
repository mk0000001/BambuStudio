# Fork CI only: compile the reviewed four-case fixture with actual app providers.
# The obsolete suite remains excluded; the existing all-ten CTest set is unchanged.
include_guard(GLOBAL)
function(bambu_add_focused_enum_map)
    foreach(_required IN ITEMS test_common libslic3r)
        if(NOT TARGET "${_required}")
            message(FATAL_ERROR "Focused enum-map provider missing: ${_required}")
        endif()
    endforeach()
    add_executable(bambu_enum_map_tests
        "${PROJECT_SOURCE_DIR}/tests/libslic3r/test_gpu_geometry_main.cpp"
        "${PROJECT_SOURCE_DIR}/tests/libslic3r/test_config_enum_maps.cpp")
    target_compile_features(bambu_enum_map_tests PRIVATE cxx_std_17)
    target_include_directories(bambu_enum_map_tests PRIVATE "${PROJECT_SOURCE_DIR}/src")
    target_link_libraries(bambu_enum_map_tests PRIVATE test_common libslic3r)
    if(MSVC)
        target_compile_definitions(bambu_enum_map_tests PRIVATE DO_NOT_USE_WMAIN)
    endif()
endfunction()
cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL bambu_add_focused_enum_map)
