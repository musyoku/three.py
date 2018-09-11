#pragma once
#include "../../header/struct.h"

void rtx_cuda_malloc(void** gpu_array, size_t size);
void rtx_cuda_memcpy_host_to_device(void* gpu_array, void* cpu_array, size_t size);
void rtx_cuda_memcpy_device_to_host(void* cpu_array, void* gpu_array, size_t size);
void rtx_cuda_free(void** array);
void cuda_device_reset();
size_t rtx_curand_state_bytes();

void rtx_cuda_init_curand_state(void*& states, int num_threads);
void rtx_cuda_render(
    RTXRay*& gpu_ray_array, const int ray_array_size,
    RTXFace*& gpu_face_vertex_index_array, const int face_vertex_index_array_size,
    RTXVertex*& gpu_vertex_array, const int vertex_array_size,
    RTXObject*& gpu_object_array, const int object_array_size,
    RTXGeometryAttribute*& gpu_geometry_attribute_array, const int geometry_attribute_array_size,
    RTXLightAttribute*& gpu_light_attribute_array, const int light_attribute_array_size,
    RTXThreadedBVH*& gpu_threaded_bvh_array, const int threaded_bvh_array_size,
    RTXThreadedBVHNode*& gpu_threaded_bvh_node_array, const int threaded_bvh_node_array_size,
    int*& gpu_light_index_array, const int light_index_array_size,
    RTXPixel*& gpu_render_array, const int render_array_size,
    const int num_threads,
    const int num_blocks,
    const int num_rays_per_pixel,
    const int max_bounce,
    const int curand_seed);

// void launch_test_linear_kernel(
//     int*& gpu_node_array, const int num_nodes);
// void launch_test_struct_kernel(
//     RTXThreadedBVHNode*& gpu_struct_array, const int num_nodes);