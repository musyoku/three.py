#include "../../../header/enum.h"
#include "../header/ray_tracing.h"
#include <assert.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <float.h>
#include <stdio.h>
#include <time.h>

__global__ void test_kernel(const float* vertices, int num_vertices)
{
    float sum = 0;
    for (int n = 0; n < num_vertices; n++) {
        float x = vertices[n * 4 + 0];
        float y = vertices[n * 4 + 1];
        float z = vertices[n * 4 + 2];
        sum += x + y + z;
    }
}

__global__ void render(
    const float* ray_buffer, const int ray_buffer_size,
    const int* face_vertex_index_buffer, const int face_vertex_index_buffer_size,
    const int* face_count_buffer, const int face_count_buffer_size,
    const float* vertex_buffer, const int vertex_buffer_size,
    const int* vertex_count_buffer, const int vertex_count_buffer_size,
    const unsigned int* scene_threaded_bvh_node_buffer, const int scene_threaded_bvh_node_buffer_size,
    const float* scene_threaded_bvh_aabb_buffer, const int scene_threaded_bvh_aabb_buffer_size,
    const float* render_buffer, const int render_buffer_size,
    const int num_rays_per_thread,
    const int num_rays,
    const int path_depth)
{
    extern __shared__ int shared_memory[];
    unsigned int thread_id = threadIdx.x;
    curandStateXORWOW_t state;
    curand_init(0, blockIdx.x * blockDim.x + threadIdx.x, 0, &state);

    int* shared_face_vertex_index_buffer = shared_memory;
    int* shared_face_count_buffer = &shared_memory[face_vertex_index_buffer_size];
    float* shared_vertex_buffer = (float*)&shared_memory[face_count_buffer_size];
    int* shared_vertex_count_buffer = &shared_memory[vertex_buffer_size];
    unsigned int* shared_scene_threaded_bvh_node_buffer = (unsigned int*)&shared_memory[vertex_count_buffer_size];
    float* shared_scene_threaded_bvh_aabb_buffer = (float*)&shared_memory[scene_threaded_bvh_node_buffer_size];
    if(thread_id == 0){
        printf("vertex_index_buffer:\n");
        for(int i = 0;i < face_vertex_index_buffer_size;i++){
            shared_face_vertex_index_buffer[i] = face_vertex_index_buffer[i];
            printf("%d ", shared_face_vertex_index_buffer[i]);
        }
        printf("\n");
        printf("face_count_buffer:\n");
        for(int i = 0;i < face_count_buffer_size;i++){
            shared_face_count_buffer[i] = face_count_buffer[i];
            printf("%d ", shared_face_count_buffer[i]);
        }
        printf("\n");
        printf("vertex_buffer:\n");
        for(int i = 0;i < vertex_buffer_size;i++){
            shared_vertex_buffer[i] = vertex_buffer[i];
            printf("%f ", shared_vertex_buffer[i]);
        }
        printf("\n");
        printf("vertex_count_buffer:\n");
        for(int i = 0;i < vertex_count_buffer_size;i++){
            shared_vertex_count_buffer[i] = vertex_count_buffer[i];
            printf("%d ", shared_vertex_count_buffer[i]);
        }
        printf("\n");
        printf("scene_threaded_bvh_node_buffer:\n");
        for(int i = 0;i < scene_threaded_bvh_node_buffer_size;i++){
            shared_scene_threaded_bvh_node_buffer[i] = scene_threaded_bvh_node_buffer[i];
            printf("%u ", shared_scene_threaded_bvh_node_buffer[i]);
        }
        printf("\n");
        printf("scene_threaded_bvh_aabb_buffer:\n");
        for(int i = 0;i < scene_threaded_bvh_aabb_buffer_size;i++){
            shared_scene_threaded_bvh_aabb_buffer[i] = scene_threaded_bvh_aabb_buffer[i];
            printf("%f ", scene_threaded_bvh_aabb_buffer[i]);
        }
        printf("\n");
    }
}

__global__ void _render(
    const float* rays,
    const float* face_vertices,
    const float* face_colors,
    const int* object_types,
    const int* material_types,
    float* color_per_ray,
    const float* camera_inv_matrix,
    const int num_rays_per_thread,
    const int thread_offset,
    const int num_rays,
    const int num_faces,
    const int faces_stride,
    const int colors_stride,
    const int max_path_depth)
{
    unsigned int tid = threadIdx.x;
    curandStateXORWOW_t state;
    curand_init(0, blockIdx.x * blockDim.x + threadIdx.x, 0, &state);

    __shared__ float shared_face_vertices[41 * 12];
    __shared__ float shared_face_colors[41 * 3];
    __shared__ int shared_object_types[41];
    __shared__ int shared_material_types[41];
    __shared__ float shared_camera_inv_matrix[4][4];

    if (threadIdx.x == 0) {
        for (int n = 0; n < num_faces; n++) {
            for (int s = 0; s < faces_stride; s++) {
                shared_face_vertices[n * faces_stride + s] = face_vertices[n * faces_stride + s];
            }
            for (int s = 0; s < colors_stride; s++) {
                shared_face_colors[n * colors_stride + s] = face_colors[n * colors_stride + s];
            }
            shared_object_types[n] = object_types[n];
            shared_material_types[n] = material_types[n];
        }
        shared_camera_inv_matrix[0][0] = camera_inv_matrix[0];
        shared_camera_inv_matrix[0][1] = camera_inv_matrix[1];
        shared_camera_inv_matrix[0][2] = camera_inv_matrix[2];
        shared_camera_inv_matrix[0][3] = camera_inv_matrix[3];
        shared_camera_inv_matrix[1][0] = camera_inv_matrix[4];
        shared_camera_inv_matrix[1][1] = camera_inv_matrix[5];
        shared_camera_inv_matrix[1][2] = camera_inv_matrix[6];
        shared_camera_inv_matrix[1][3] = camera_inv_matrix[7];
        shared_camera_inv_matrix[2][0] = camera_inv_matrix[8];
        shared_camera_inv_matrix[2][1] = camera_inv_matrix[9];
        shared_camera_inv_matrix[2][2] = camera_inv_matrix[10];
        shared_camera_inv_matrix[2][3] = camera_inv_matrix[11];
        shared_camera_inv_matrix[3][0] = camera_inv_matrix[12];
        shared_camera_inv_matrix[3][1] = camera_inv_matrix[13];
        shared_camera_inv_matrix[3][2] = camera_inv_matrix[14];
        shared_camera_inv_matrix[3][3] = camera_inv_matrix[15];
    }
    __syncthreads();

    for (int n = 0; n < num_rays_per_thread; n++) {
        unsigned int ray_index = (blockIdx.x * blockDim.x + threadIdx.x) * num_rays_per_thread + n + thread_offset;
        if (ray_index >= num_rays) {
            return;
        }

        const int p = ray_index * 7;
        float ray_direction_x = rays[p + 0];
        float ray_direction_y = rays[p + 1];
        float ray_direction_z = rays[p + 2];
        float ray_origin_x = rays[p + 3];
        float ray_origin_y = rays[p + 4];
        float ray_origin_z = rays[p + 5];
        float ray_direction_inv_x = 1.0f / ray_direction_x;
        float ray_direction_inv_y = 1.0f / ray_direction_y;
        float ray_direction_inv_z = 1.0f / ray_direction_z;

        float color_r = 0.0;
        float color_g = 0.0;
        float color_b = 0.0;

        int object_type = 0;
        int material_type = 0;
        float hit_point_x = 0.0f;
        float hit_point_y = 0.0f;
        float hit_point_z = 0.0f;
        float hit_color_r = 0.0f;
        float hit_color_g = 0.0f;
        float hit_color_b = 0.0f;
        float hit_face_normal_x = 0.0f;
        float hit_face_normal_y = 0.0f;
        float hit_face_normal_z = 0.0f;

        color_r = 1.0f;
        color_g = 1.0f;
        color_b = 1.0f;

        const float eps = 0.0000001;
        float reflection_decay_r = 1.0f;
        float reflection_decay_g = 1.0f;
        float reflection_decay_b = 1.0f;
        bool did_hit_light = false;

        for (int depth = 0; depth < max_path_depth; depth++) {
            float min_distance = FLT_MAX;
            bool did_hit_object = false;

            for (int face_index = 0; face_index < num_faces; face_index++) {
                object_type = shared_object_types[face_index];
                const int index = face_index * faces_stride;

                if (object_type == RTX_GEOMETRY_TYPE_STANDARD) {
                    const float va_x = shared_face_vertices[index + 0];
                    const float va_y = shared_face_vertices[index + 1];
                    const float va_z = shared_face_vertices[index + 2];

                    const float vb_x = shared_face_vertices[index + 4];
                    const float vb_y = shared_face_vertices[index + 5];
                    const float vb_z = shared_face_vertices[index + 6];

                    const float vc_x = shared_face_vertices[index + 8];
                    const float vc_y = shared_face_vertices[index + 9];
                    const float vc_z = shared_face_vertices[index + 10];

                    const float edge_ba_x = vb_x - va_x;
                    const float edge_ba_y = vb_y - va_y;
                    const float edge_ba_z = vb_z - va_z;

                    const float edge_ca_x = vc_x - va_x;
                    const float edge_ca_y = vc_y - va_y;
                    const float edge_ca_z = vc_z - va_z;

                    const float h_x = ray_direction_y * edge_ca_z - ray_direction_z * edge_ca_y;
                    const float h_y = ray_direction_z * edge_ca_x - ray_direction_x * edge_ca_z;
                    const float h_z = ray_direction_x * edge_ca_y - ray_direction_y * edge_ca_x;
                    const float a = edge_ba_x * h_x + edge_ba_y * h_y + edge_ba_z * h_z;
                    if (a > -eps && a < eps) {
                        continue;
                    }
                    const float f = 1.0f / a;

                    const float s_x = ray_origin_x - va_x;
                    const float s_y = ray_origin_y - va_y;
                    const float s_z = ray_origin_z - va_z;
                    float dot = s_x * h_x + s_y * h_y + s_z * h_z;
                    const float u = f * dot;
                    if (u < 0.0f || u > 1.0f) {
                        continue;
                    }
                    const float q_x = s_y * edge_ba_z - s_z * edge_ba_y;
                    const float q_y = s_z * edge_ba_x - s_x * edge_ba_z;
                    const float q_z = s_x * edge_ba_y - s_y * edge_ba_x;
                    dot = q_x * ray_direction_x + q_y * ray_direction_y + q_z * ray_direction_z;
                    const float v = f * dot;
                    if (v < 0.0f || u + v > 1.0f) {
                        continue;
                    }
                    float tmp_x = edge_ba_y * edge_ca_z - edge_ba_z * edge_ca_y;
                    float tmp_y = edge_ba_z * edge_ca_x - edge_ba_x * edge_ca_z;
                    float tmp_z = edge_ba_x * edge_ca_y - edge_ba_y * edge_ca_x;

                    float norm = sqrtf(tmp_x * tmp_x + tmp_y * tmp_y + tmp_z * tmp_z) + 1e-12;

                    tmp_x = tmp_x / norm;
                    tmp_y = tmp_y / norm;
                    tmp_z = tmp_z / norm;

                    dot = tmp_x * ray_direction_x + tmp_y * ray_direction_y + tmp_z * ray_direction_z;
                    if (dot > 0.0f) {
                        continue;
                    }

                    dot = edge_ca_x * q_x + edge_ca_y * q_y + edge_ca_z * q_z;
                    const float t = f * dot;

                    if (t <= 0.001f) {
                        continue;
                    }
                    if (min_distance <= t) {
                        continue;
                    }

                    min_distance = t;
                    hit_point_x = ray_origin_x + t * ray_direction_x;
                    hit_point_y = ray_origin_y + t * ray_direction_y;
                    hit_point_z = ray_origin_z + t * ray_direction_z;

                    hit_face_normal_x = tmp_x;
                    hit_face_normal_y = tmp_y;
                    hit_face_normal_z = tmp_z;

                    material_type = shared_material_types[face_index];

                    hit_color_r = shared_face_colors[face_index * colors_stride + 0];
                    hit_color_g = shared_face_colors[face_index * colors_stride + 1];
                    hit_color_b = shared_face_colors[face_index * colors_stride + 2];

                    did_hit_object = true;
                    continue;
                }
                if (object_type == RTX_GEOMETRY_TYPE_SPHERE) {
                    const float center_x = shared_face_vertices[index + 0];
                    const float center_y = shared_face_vertices[index + 1];
                    const float center_z = shared_face_vertices[index + 2];
                    const float radius = shared_face_vertices[index + 4];

                    const float oc_x = ray_origin_x - center_x;
                    const float oc_y = ray_origin_y - center_y;
                    const float oc_z = ray_origin_z - center_z;

                    const float a = ray_direction_x * ray_direction_x + ray_direction_y * ray_direction_y + ray_direction_z * ray_direction_z;
                    const float b = 2.0f * (ray_direction_x * oc_x + ray_direction_y * oc_y + ray_direction_z * oc_z);
                    const float c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - radius * radius;
                    const float d = b * b - 4.0f * a * c;

                    if (d <= 0) {
                        continue;
                    }
                    const float root = sqrt(d);
                    float t = (-b - root) / (2.0f * a);
                    if (t <= 0.001f) {
                        t = (-b + root) / (2.0f * a);
                        if (t <= 0.001f) {
                            continue;
                        }
                    }

                    if (min_distance <= t) {
                        continue;
                    }
                    min_distance = t;
                    hit_point_x = ray_origin_x + t * ray_direction_x;
                    hit_point_y = ray_origin_y + t * ray_direction_y;
                    hit_point_z = ray_origin_z + t * ray_direction_z;

                    float tmp_x = hit_point_x - center_x;
                    float tmp_y = hit_point_y - center_y;
                    float tmp_z = hit_point_z - center_z;
                    float norm = sqrtf(tmp_x * tmp_x + tmp_y * tmp_y + tmp_z * tmp_z) + 1e-12;

                    hit_face_normal_x = tmp_x / norm;
                    hit_face_normal_y = tmp_y / norm;
                    hit_face_normal_z = tmp_z / norm;

                    material_type = shared_material_types[face_index];

                    hit_color_r = shared_face_colors[face_index * colors_stride + 0];
                    hit_color_g = shared_face_colors[face_index * colors_stride + 1];
                    hit_color_b = shared_face_colors[face_index * colors_stride + 2];

                    did_hit_object = true;
                    continue;
                }
                // http://www.cs.utah.edu/~awilliam/box/box.pdf
                if (object_type == 333) {
                    float _min_x = shared_face_vertices[index + 0];
                    float _min_y = shared_face_vertices[index + 1];
                    float _min_z = shared_face_vertices[index + 2];
                    float _max_x = shared_face_vertices[index + 4];
                    float _max_y = shared_face_vertices[index + 5];
                    float _max_z = shared_face_vertices[index + 6];

                    float min_x = shared_camera_inv_matrix[0][0] * _min_x + shared_camera_inv_matrix[1][0] * _min_y + shared_camera_inv_matrix[2][0] * _min_z + shared_camera_inv_matrix[3][0];
                    float min_y = shared_camera_inv_matrix[0][1] * _min_x + shared_camera_inv_matrix[1][1] * _min_y + shared_camera_inv_matrix[2][1] * _min_z + shared_camera_inv_matrix[3][1];
                    float min_z = shared_camera_inv_matrix[0][2] * _min_x + shared_camera_inv_matrix[1][2] * _min_y + shared_camera_inv_matrix[2][2] * _min_z + shared_camera_inv_matrix[3][2];

                    float max_x = shared_camera_inv_matrix[0][0] * _max_x + shared_camera_inv_matrix[1][0] * _max_y + shared_camera_inv_matrix[2][0] * _max_z + shared_camera_inv_matrix[3][0];
                    float max_y = shared_camera_inv_matrix[0][1] * _max_x + shared_camera_inv_matrix[1][1] * _max_y + shared_camera_inv_matrix[2][1] * _max_z + shared_camera_inv_matrix[3][1];
                    float max_z = shared_camera_inv_matrix[0][2] * _max_x + shared_camera_inv_matrix[1][2] * _max_y + shared_camera_inv_matrix[2][2] * _max_z + shared_camera_inv_matrix[3][2];

                    const bool sign_x = ray_direction_inv_x < 0;
                    const bool sign_y = ray_direction_inv_y < 0;
                    const bool sign_z = ray_direction_inv_z < 0;
                    float tmin, tmax, tymin, tymax, tzmin, tzmax;
                    tmin = ((sign_x ? max_x : min_x) - ray_origin_x) * ray_direction_inv_x;
                    tmax = ((sign_x ? min_x : max_x) - ray_origin_x) * ray_direction_inv_x;
                    tymin = ((sign_y ? max_y : min_y) - ray_origin_y) * ray_direction_inv_y;
                    tymax = ((sign_y ? min_y : max_y) - ray_origin_y) * ray_direction_inv_y;
                    if ((tmin > tymax) || (tymin > tmax)) {
                        continue;
                    }
                    if (tymin > tmin) {
                        tmin = tymin;
                    }
                    if (tymax < tmax) {
                        tmax = tymax;
                    }
                    tzmin = ((sign_z ? max_z : min_z) - ray_origin_z) * ray_direction_inv_z;
                    tzmax = ((sign_z ? min_z : max_z) - ray_origin_z) * ray_direction_inv_z;
                    if ((tmin > tzmax) || (tzmin > tmax)) {
                        continue;
                    }
                    if (tzmin > tmin) {
                        tmin = tzmin;
                    }
                    if (tzmax < tmax) {
                        tmax = tzmax;
                    }
                    material_type = RTX_MATERIAL_TYPE_EMISSIVE;

                    hit_color_r = 1.0f;
                    hit_color_g = 1.0f;
                    hit_color_b = 1.0f;

                    did_hit_object = true;
                    continue;
                }
            }

            if (did_hit_object) {
                ray_origin_x = hit_point_x;
                ray_origin_y = hit_point_y;
                ray_origin_z = hit_point_z;

                if (material_type == RTX_MATERIAL_TYPE_EMISSIVE) {
                    color_r = reflection_decay_r * hit_color_r;
                    color_g = reflection_decay_g * hit_color_g;
                    color_b = reflection_decay_b * hit_color_b;
                    did_hit_light = true;
                    break;
                }

                // detect backface
                // float dot = hit_face_normal_x * ray_direction_x + hit_face_normal_y * ray_direction_y + hit_face_normal_z * ray_direction_z;
                // if (dot > 0.0f) {
                //     hit_face_normal_x *= -1.0f;
                //     hit_face_normal_y *= -1.0f;
                //     hit_face_normal_z *= -1.0f;
                // }

                // diffuse reflection
                float diffuese_x = curand_normal(&state);
                float diffuese_y = curand_normal(&state);
                float diffuese_z = curand_normal(&state);
                const float norm = sqrt(diffuese_x * diffuese_x + diffuese_y * diffuese_y + diffuese_z * diffuese_z);
                diffuese_x /= norm;
                diffuese_y /= norm;
                diffuese_z /= norm;

                float dot = hit_face_normal_x * diffuese_x + hit_face_normal_y * diffuese_y + hit_face_normal_z * diffuese_z;
                if (dot < 0.0f) {
                    diffuese_x = -diffuese_x;
                    diffuese_y = -diffuese_y;
                    diffuese_z = -diffuese_z;
                }
                ray_direction_x = diffuese_x;
                ray_direction_y = diffuese_y;
                ray_direction_z = diffuese_z;

                ray_direction_inv_x = 1.0f / ray_direction_x;
                ray_direction_inv_y = 1.0f / ray_direction_y;
                ray_direction_inv_z = 1.0f / ray_direction_z;

                reflection_decay_r *= hit_color_r;
                reflection_decay_g *= hit_color_g;
                reflection_decay_b *= hit_color_b;
            }
        }

        if (did_hit_light == false) {
            color_r = 0.0f;
            color_g = 0.0f;
            color_b = 0.0f;
        }
        color_per_ray[ray_index * 3 + 0] = color_r;
        color_per_ray[ray_index * 3 + 1] = color_g;
        color_per_ray[ray_index * 3 + 2] = color_b;
    }
}
void rtx_cuda_malloc(void** gpu_buffer, size_t size)
{
    cudaError_t error = cudaMalloc(gpu_buffer, size);
    printf("malloc %p\n", *gpu_buffer);
    cudaError_t status = cudaGetLastError();
    if (error != cudaSuccess) {
        fprintf(stderr, "CUDA Error at cudaMalloc: %s\n", cudaGetErrorString(error));
    }
}
void rtx_cuda_memcpy_host_to_device(void* gpu_buffer, void* cpu_buffer, size_t size)
{
    cudaError_t error = cudaMemcpy(gpu_buffer, cpu_buffer, size, cudaMemcpyHostToDevice);
    if (error != cudaSuccess) {
        fprintf(stderr, "CUDA Error at cudaMemcpyHostToDevice: %s\n", cudaGetErrorString(error));
    }
}
void rtx_cuda_memcpy_device_to_host(void* cpu_buffer, void* gpu_buffer, size_t size)
{
    cudaError_t error = cudaMemcpy(cpu_buffer, gpu_buffer, size, cudaMemcpyDeviceToHost);
    if (error != cudaSuccess) {
        fprintf(stderr, "CUDA Error at cudaMemcpyDeviceToHost: %s\n", cudaGetErrorString(error));
    }
}
void rtx_cuda_free(void** buffer)
{
    if (*buffer != NULL) {
        printf("free %p\n", *buffer);
        cudaError_t error = cudaFree(*buffer);
        if (error != cudaSuccess) {
            fprintf(stderr, "CUDA Error at cudaFree: %s\n", cudaGetErrorString(error));
        }
        *buffer = NULL;
    }
}
void cuda_device_reset()
{
    cudaDeviceReset();
}
void rtx_cuda_ray_tracing_render(
    float*& gpu_ray_buffer, const int ray_buffer_size,
    int*& gpu_face_vertex_index_buffer, const int face_vertex_index_buffer_size,
    int*& gpu_face_count_buffer, const int face_count_buffer_size,
    float*& gpu_vertex_buffer, const int vertex_buffer_size,
    int*& gpu_vertex_count_buffer, const int vertex_count_buffer_size,
    unsigned int*& gpu_scene_threaded_bvh_node_buffer, const int scene_threaded_bvh_node_buffer_size,
    float*& gpu_scene_threaded_bvh_aabb_buffer, const int scene_threaded_bvh_aabb_buffer_size,
    float*& gpu_render_buffer, const int render_buffer_size,
    const int num_rays,
    const int num_rays_per_pixel,
    const int max_path_depth)
{
    assert(gpu_ray_buffer != NULL);
    assert(gpu_face_vertex_index_buffer != NULL);
    assert(gpu_face_count_buffer != NULL);
    assert(gpu_vertex_buffer != NULL);
    assert(gpu_vertex_count_buffer != NULL);
    assert(gpu_scene_threaded_bvh_node_buffer != NULL);
    assert(gpu_scene_threaded_bvh_aabb_buffer != NULL);
    assert(gpu_render_buffer != NULL);

    int num_threads = 128;
    int num_blocks = (num_rays - 1) / num_threads + 1;

    num_blocks = 1;

    int num_kernels = 1;
    assert(num_rays % num_kernels == 0);

    int num_rays_per_thread = num_rays / (num_threads * num_blocks * num_kernels) + 1;
    int num_rays_per_kernel = num_rays / num_kernels;

    int shared_memory_bytes = sizeof(float) * (vertex_buffer_size + scene_threaded_bvh_aabb_buffer_size) + sizeof(int) * (face_vertex_index_buffer_size + face_count_buffer_size + vertex_count_buffer_size) + sizeof(unsigned int) * (scene_threaded_bvh_node_buffer_size);

    printf("shared memory: %d bytes\n", shared_memory_bytes);

    // printf("rays: %d, rays_per_kernel: %d, num_rays_per_thread: %d\n", num_rays, num_rays_per_kernel, num_rays_per_thread);
    // printf("<<<%d, %d>>>\n", num_blocks, num_threads);
    render<<<num_blocks, num_threads, shared_memory_bytes>>>(
        gpu_ray_buffer, ray_buffer_size,
        gpu_face_vertex_index_buffer, face_vertex_index_buffer_size,
        gpu_face_count_buffer, face_count_buffer_size,
        gpu_vertex_buffer, vertex_buffer_size,
        gpu_vertex_count_buffer, vertex_count_buffer_size,
        gpu_scene_threaded_bvh_node_buffer, scene_threaded_bvh_node_buffer_size,
        gpu_scene_threaded_bvh_aabb_buffer, scene_threaded_bvh_aabb_buffer_size,
        gpu_render_buffer, render_buffer_size,
        num_rays_per_thread,
        num_rays,
        max_path_depth);
    cudaError_t status = cudaGetLastError();
    if (status != 0) {
        fprintf(stderr, "CUDA Error at kernel: %s\n", cudaGetErrorString(status));
    }
    cudaError_t error = cudaThreadSynchronize();
    if (error != cudaSuccess) {
        fprintf(stderr, "CUDA Error at cudaThreadSynchronize: %s\n", cudaGetErrorString(error));
    }

    // cudaDeviceProp dev;
    // cudaGetDeviceProperties(&dev, 0);

    // printf(" device name : %s\n", dev.name);
    // printf(" total global memory : %d (MB)\n", dev.totalGlobalMem/1024/1024);
    // printf(" shared memory / block : %d (KB)\n", dev.sharedMemPerBlock/1024);
    // printf(" register / block : %d\n", dev.regsPerBlock);
}

// void rtx_launch_test_kernel()
// {
//     clock_t c1, c2;

//     int num_vertices = 100000;
//     float* vertices = (float*)malloc(sizeof(float) * num_vertices * 4);
//     for (int n = 0; n < num_vertices; n++) {
//         vertices[n * 4 + 0] = 0.1f;
//         vertices[n * 4 + 1] = 0.1f;
//         vertices[n * 4 + 2] = 0.1f;
//         vertices[n * 4 + 3] = 0.1f;
//     }
//     float* gpu_vertices;
//     cudaMalloc((void**)&gpu_vertices, sizeof(float) * num_vertices * 4);
//     cudaMemcpy(gpu_vertices, vertices, sizeof(float) * num_vertices * 4, cudaMemcpyHostToDevice);

//     double mean = 0.0f;
//     for (int j = 0; j < 10; j++) {
//         c1 = clock();
//         for (int i = 0; i < 1000; i++) {
//             test_kernel<<<512, 128>>>(gpu_vertices, num_vertices);
//             cudaThreadSynchronize();
//         }
//         c2 = clock();
//         mean += (double)(c2 - c1) / CLOCKS_PER_SEC;
//     }
//     printf("time = %lf[s]\n", mean / 10.0);
//     free(vertices);
//     cudaFree(gpu_vertices);

//     size_t pitch;
//     cudaMallocPitch((void**)&gpu_vertices, &pitch, sizeof(float) * num_vertices * 4, 1);

//     cudaError_t status = cudaGetLastError();
//     if (status != 0) {
//         fprintf(stderr, "%s\n", cudaGetErrorString(status));
//     }

//     printf("pitch = %d\n", (int)(pitch));
//     cudaMemcpy(gpu_vertices, vertices, sizeof(float) * num_vertices * 4, cudaMemcpyHostToDevice);

//     status = cudaGetLastError();
//     if (status != 0) {
//         fprintf(stderr, "%s\n", cudaGetErrorString(status));
//     }

//     mean = 0.0f;
//     for (int j = 0; j < 10; j++) {
//         c1 = clock();
//         for (int i = 0; i < 1000; i++) {
//             test_kernel<<<512, 128>>>(gpu_vertices, num_vertices);
//             cudaThreadSynchronize();
//         }
//         c2 = clock();
//         mean += (double)(c2 - c1) / CLOCKS_PER_SEC;
//     }
//     printf("time = %lf[s]\n", mean / 10.0);
//     free(vertices);
//     cudaFree(gpu_vertices);
// }