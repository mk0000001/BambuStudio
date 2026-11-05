get_filename_component(_TEST_NAME ${CMAKE_CURRENT_LIST_DIR} NAME)

add_executable(${_TEST_NAME}_tests 
	${_TEST_NAME}_tests.cpp
	test_3mf.cpp
	test_aabbindirect.cpp
	test_clipper_offset.cpp
	test_clipper_utils.cpp
	test_config.cpp
	test_elephant_foot_compensation.cpp
	test_geometry.cpp
	test_placeholder_parser.cpp
	test_polygon.cpp
	test_mutable_polygon.cpp
	test_mutable_priority_queue.cpp
	test_stl.cpp
	test_meshboolean.cpp
	test_marchingsquares.cpp
	test_timeutils.cpp
	test_voronoi.cpp
    test_optimizers.cpp
    test_png_io.cpp
    test_timeutils.cpp
    test_indexed_triangle_set.cpp
    test_triangle_selector.cpp
    test_debounce.cpp
    test_emboss.cpp
    ../libnest2d/printer_parts.cpp
	)

if (TARGET OpenVDB::openvdb)
    target_sources(${_TEST_NAME}_tests PRIVATE test_hollowing.cpp)
endif()

target_link_libraries(${_TEST_NAME}_tests test_common libslic3r)
set_property(TARGET ${_TEST_NAME}_tests PROPERTY FOLDER "tests")

if (WIN32)
    # bambustudio_copy_dlls now requires 4 args (target, config, postfix,
    # output_dlls); legacy 1-arg call sites in tests/* predate that signature
    # change.  Test executables link libslic3r and do not need the heavyweight
    # OCCT / GMP / MPFR / FFmpeg DLL bundle, so skip the copy step here.
    # Run tests with PATH pointing at deps build dir if extra DLLs are needed.
    # bambustudio_copy_dlls(${_TEST_NAME}_tests <config> <postfix> <out>)
endif()

# catch_discover_tests(${_TEST_NAME}_tests TEST_PREFIX "${_TEST_NAME}: ")
add_test(${_TEST_NAME}_tests ${_TEST_NAME}_tests ${CATCH_EXTRA_ARGS})

# This production candidate visitor is independent of optional GPU toolchains.
add_executable(gpu_rectilinear_candidates_tests test_gpu_rectilinear_candidates.cpp)
set_property(TARGET gpu_rectilinear_candidates_tests PROPERTY CXX_STANDARD 17)
add_test(NAME gpu_rectilinear_candidates_tests COMMAND gpu_rectilinear_candidates_tests)

if(SLIC3R_ENABLE_CUDA_SLICER OR SLIC3R_ENABLE_VULKAN_SLICER)
    target_sources(${_TEST_NAME}_tests PRIVATE test_gpu_rectilinear_equivalence.cpp)
endif()

add_executable(gpu_tree_candidates_tests test_gpu_tree_candidates.cpp)
set_property(TARGET gpu_tree_candidates_tests PROPERTY CXX_STANDARD 17)
add_test(NAME gpu_tree_candidates_tests COMMAND gpu_tree_candidates_tests)

# The same production gate suite also runs with the product's native Catch
# version when GPU support is built; standalone tests/gpu_safety covers OFF.
if(SLIC3R_ENABLE_CUDA_SLICER OR SLIC3R_ENABLE_VULKAN_SLICER)
    target_sources(${_TEST_NAME}_tests PRIVATE
        test_gpu_exact_geometry.cpp test_gpu_batch_preflight.cpp)
endif()
