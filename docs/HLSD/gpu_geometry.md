# Optional exact GPU geometry

CUDA and Vulkan accelerate strict-interior rational scanline intersections in rectilinear fill. CPU code retains vertices, winding, sorting, clipping and toolpath construction. Vulkan additionally rejects tree-support branch pairs only when their bounding boxes are disjoint from every whole filled-contour box; all candidates retain exact CPU clipping. CUDA does not implement that tree stage.

Both build options, `SLIC3R_ENABLE_CUDA_SLICER` and `SLIC3R_ENABLE_VULKAN_SLICER`, default OFF. GPU-enabled builds still default to CPU at runtime. Set `SLIC3R_GPU_BACKEND=cpu|cuda|vulkan|auto` before starting the application to opt in; unknown values select CPU. Auto tries CUDA, then Vulkan, then CPU. No project/profile format or G-code writer changes are involved.

Every input is preflighted with signed 256-bit host arithmetic against the actual device int64 intermediates and the destination uint32 denominator. Unsafe or oversized batches retain the original CPU path. Every returned record is validated in order against an independent wide reference before any record reaches the topology code. Failures discard the complete batch and quarantine that backend for the process. Full validation and transfers may cost more than the arithmetic saved: GPU utilization alone establishes no speedup. Measure complete slices including host work.

Shared CUDA state is serialized and device-wide resets are avoided. Vulkan initialization, qualification, dispatch and staging cleanup use the same resource lock. Both Vulkan dispatch paths emit a compute shader write to host read memory dependency before fence completion and host access. Returned API failures fall back; a synchronous driver call that never returns cannot be guaranteed to recover.

CUDA12.x is required to compile Pascal sm61, including GTX1060. Vulkan requires a suitable compute queue, shaderInt64 and generated SPIR-V resources. The app supplies its installed resource directory before first use; FHS and bundle packages must retain their generated `vulkan` resource subdirectory. Unsupported devices use CPU.

`SLIC3R_GPU_SELFTEST=ON` builds a compute diagnostic. A CPU-only diagnostic is not a GPU kernel run. Backend qualification, actual hardware dispatch, ordered geometry comparisons and whole-application tests are required before describing a binary as validated or faster. The standalone contract suite is built from `tests/gpu_safety`.
