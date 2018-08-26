#include "../header/ray_tracing.h"
#include <assert.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <float.h>
#include <stdio.h>

// __device__ float intersect_sphere(
//     const float center_x,
//     const float center_y,
//     const float center_z,
//     const float radius,
//     const float ray_direction_x,
//     const float ray_direction_y,
//     const float ray_direction_z,
//     const float ray_origin_x,
//     const float ray_origin_y,
//     const float ray_origin_z)
// {
//     const float oc_x = ray_origin_x - center_x;
//     const float oc_y = ray_origin_y - center_y;
//     const float oc_z = ray_origin_z - center_z;

//     const float a = ray_direction_x * ray_direction_x + ray_direction_y * ray_direction_y + ray_direction_z * ray_direction_z;
//     const float b = 2.0f * (ray_direction_x * oc_x + ray_direction_y * oc_y + ray_direction_z * oc_z);
//     const float c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - radius * radius;
//     const float d = b * b - 4.0f * a * c;

//     if (d <= 0) {
//         return -1.0f;
//     }
//     const float root = sqrt(d);
//     const float t0 = (-b - root) / (2.0f * a);
//     if (t0 > 0.001f) {
//         return t0;
//     }
//     const float t1 = (-b + root) / (2.0f * a);
//     if (t1 > 0.001f) {
//         return t1;
//     }
//     return -1.0f;
// }

// __device__ bool hit_test(
//     const float* face_vertices,
//     const float* face_colors,
//     const int* object_types,
//     const int* material_types,
//     const int num_faces,
//     const int faces_stride,
//     const int colors_stride,
//     const int ray_index,
//     int& object_type,
//     int& material_type,
//     float ray_direction_x,
//     float ray_direction_y,
//     float ray_direction_z,
//     float ray_origin_x,
//     float ray_origin_y,
//     float ray_origin_z,
//     float& hit_point_x,
//     float& hit_point_y,
//     float& hit_point_z,
//     float& hit_color_r,
//     float& hit_color_g,
//     float& hit_color_b,
//     float& face_normal_x,
//     float& face_normal_y,
//     float& face_normal_z)
// {
//     float min_distance = FLT_MAX;
//     bool did_hit_object = false;
//     const float eps = 0.0000001;

//     for (int face_index = 0; face_index < num_faces; face_index++) {
//         object_type = object_types[face_index];
//         const int index = face_index * faces_stride;

//         if (object_type == RTX_CUDA_GEOMETRY_TYPE_STANDARD) {
//             const float va_x = face_vertices[index + 0];
//             const float va_y = face_vertices[index + 1];
//             const float va_z = face_vertices[index + 2];
//             const float va_w = face_vertices[index + 3];

//             const float vb_x = face_vertices[index + 4];
//             const float vb_y = face_vertices[index + 5];
//             const float vb_z = face_vertices[index + 6];
//             const float vb_w = face_vertices[index + 7];

//             const float vc_x = face_vertices[index + 8];
//             const float vc_y = face_vertices[index + 9];
//             const float vc_z = face_vertices[index + 10];
//             const float vc_w = face_vertices[index + 11];

//             const float edge_ba_x = vb_x - va_x;
//             const float edge_ba_y = vb_y - va_y;
//             const float edge_ba_z = vb_z - va_z;

//             const float edge_ca_x = vc_x - va_x;
//             const float edge_ca_y = vc_y - va_y;
//             const float edge_ca_z = vc_z - va_z;

//             const float h_x = ray_direction_y * edge_ca_z - ray_direction_z * edge_ca_y;
//             const float h_y = ray_direction_z * edge_ca_x - ray_direction_x * edge_ca_z;
//             const float h_z = ray_direction_x * edge_ca_y - ray_direction_y * edge_ca_x;
//             const float a = edge_ba_x * h_x + edge_ba_y * h_y + edge_ba_z * h_z;
//             if (a > -eps && a < eps) {
//                 continue;
//             }
//             const float f = 1.0f / a;

//             const float s_x = ray_origin_x - va_x;
//             const float s_y = ray_origin_y - va_y;
//             const float s_z = ray_origin_z - va_z;
//             float dot = s_x * h_x + s_y * h_y + s_z * h_z;
//             const float u = f * dot;
//             if (u < 0.0f || u > 1.0f) {
//                 continue;
//             }
//             const float q_x = s_y * edge_ba_z - s_z * edge_ba_y;
//             const float q_y = s_z * edge_ba_x - s_x * edge_ba_z;
//             const float q_z = s_x * edge_ba_y - s_y * edge_ba_x;
//             dot = q_x * ray_direction_x + q_y * ray_direction_y + q_z * ray_direction_z;
//             const float v = f * dot;
//             if (v < 0.0f || u + v > 1.0f) {
//                 continue;
//             }
//             dot = edge_ca_x * q_x + edge_ca_y * q_y + edge_ca_z * q_z;
//             const float t = f * dot;

//             if (t <= 0.001f) {
//                 continue;
//             }
//             if (min_distance <= t) {
//                 continue;
//             }
//             min_distance = t;
//             hit_point_x = ray_origin_x + t * ray_direction_x;
//             hit_point_y = ray_origin_y + t * ray_direction_y;
//             hit_point_z = ray_origin_z + t * ray_direction_z;

//             float tmp_x = edge_ba_y * edge_ca_z - edge_ba_z * edge_ca_y;
//             float tmp_y = edge_ba_z * edge_ca_x - edge_ba_x * edge_ca_z;
//             float tmp_z = edge_ba_x * edge_ca_y - edge_ba_y * edge_ca_x;

//             float norm = sqrtf(tmp_x * tmp_x + tmp_y * tmp_y + tmp_z * tmp_z) + 1e-12;

//             face_normal_x = tmp_x / norm;
//             face_normal_y = tmp_y / norm;
//             face_normal_z = tmp_z / norm;

//             material_type = material_types[face_index];

//             hit_color_r = face_colors[face_index * colors_stride + 0];
//             hit_color_g = face_colors[face_index * colors_stride + 1];
//             hit_color_b = face_colors[face_index * colors_stride + 2];

//             did_hit_object = true;
//         }
//         if (object_type == RTX_CUDA_GEOMETRY_TYPE_SPHERE) {
//             const float center_x = face_vertices[index + 0];
//             const float center_y = face_vertices[index + 1];
//             const float center_z = face_vertices[index + 2];
//             const float center_w = face_vertices[index + 3];
//             const float radius = face_vertices[index + 4];

//             const float t = intersect_sphere(
//                 center_x, center_y, center_z,
//                 radius,
//                 ray_direction_x, ray_direction_y, ray_direction_z,
//                 ray_origin_x, ray_origin_y, ray_origin_z);
//             if (t <= 0.001f) {
//                 continue;
//             }
//             if (min_distance <= t) {
//                 continue;
//             }
//             min_distance = t;
//             hit_point_x = ray_origin_x + t * ray_direction_x;
//             hit_point_y = ray_origin_y + t * ray_direction_y;
//             hit_point_z = ray_origin_z + t * ray_direction_z;

//             float tmp_x = hit_point_x - center_x;
//             float tmp_y = hit_point_y - center_y;
//             float tmp_z = hit_point_z - center_z;
//             float norm = sqrtf(tmp_x * tmp_x + tmp_y * tmp_y + tmp_z * tmp_z) + 1e-12;

//             face_normal_x = tmp_x / norm;
//             face_normal_y = tmp_y / norm;
//             face_normal_z = tmp_z / norm;

//             material_type = material_types[face_index];

//             hit_color_r = face_colors[face_index * colors_stride + 0];
//             hit_color_g = face_colors[face_index * colors_stride + 1];
//             hit_color_b = face_colors[face_index * colors_stride + 2];

//             did_hit_object = true;
//         }
//     }
//     return did_hit_object;
// }

// __device__ void compute_color(
//     const float* face_vertices,
//     const int* object_types,
//     const int num_faces,
//     const int faces_stride,
//     const int current_path_depth,
//     const int max_path_depth,
//     const int ray_index,
//     curandStateXORWOW_t& state,
//     float& ray_direction_x,
//     float& ray_direction_y,
//     float& ray_direction_z,
//     float& ray_origin_x,
//     float& ray_origin_y,
//     float& ray_origin_z,
//     float& color_r,
//     float& color_g,
//     float& color_b)
// {
//     if (current_path_depth >= max_path_depth) {
//         color_r = 0.0f;
//         color_g = 0.0f;
//         color_b = 0.0f;
//         return;
//     }
//     int object_type = -1;
//     float hit_point_x = 0.0f;
//     float hit_point_y = 0.0f;
//     float hit_point_z = 0.0f;
//     float hit_face_normal_x = 0.0f;
//     float hit_face_normal_y = 0.0f;
//     float hit_face_normal_z = 0.0f;

//     color_r = 1.0f;
//     color_g = 1.0f;
//     color_b = 1.0f;

//     for (int depth = 0; depth < 1; depth++) {
//         if (hit_test(face_vertices, object_types, num_faces, faces_stride, ray_index, object_type,
//                 ray_direction_x, ray_direction_y, ray_direction_z,
//                 ray_origin_x, ray_origin_y, ray_origin_z,
//                 hit_point_x, hit_point_y, hit_point_z,
//                 hit_face_normal_x, hit_face_normal_y, hit_face_normal_z)) {
//             ray_origin_x = hit_point_x;
//             ray_origin_y = hit_point_y;
//             ray_origin_z = hit_point_z;

//             // diffuse reflection
//             float diffuese_x = curand_normal(&state);
//             float diffuese_y = curand_normal(&state);
//             float diffuese_z = curand_normal(&state);
//             const float norm = sqrt(diffuese_x * diffuese_x + diffuese_y * diffuese_y + diffuese_z * diffuese_z);
//             diffuese_x /= norm;
//             diffuese_y /= norm;
//             diffuese_z /= norm;
//             float dot = hit_face_normal_x * diffuese_x + hit_face_normal_y * diffuese_y + hit_face_normal_z * diffuese_z;
//             if (dot < 0.0f) {
//                 diffuese_x = -diffuese_x;
//                 diffuese_y = -diffuese_y;
//                 diffuese_z = -diffuese_z;
//             }
//             ray_direction_x = diffuese_x;
//             ray_direction_y = diffuese_y;
//             ray_direction_z = diffuese_z;

//             color_r *= 0.8;
//             color_g *= 0.8;
//             color_b *= 0.8;

//             color_r = (diffuese_x + 1.0f) * 0.5;
//             color_g = (diffuese_y + 1.0f) * 0.5;
//             color_b = (diffuese_z + 1.0f) * 0.5;
//         } else {
//             color_r = 1;
//             color_g = 0;
//             color_b = 0;
//         }
//     }
//     return;

//     if (hit_test(face_vertices, object_types, num_faces, faces_stride, ray_index, object_type,
//             ray_direction_x, ray_direction_y, ray_direction_z,
//             ray_origin_x, ray_origin_y, ray_origin_z,
//             hit_point_x, hit_point_y, hit_point_z,
//             hit_face_normal_x, hit_face_normal_y, hit_face_normal_z)) {
//         ray_origin_x = hit_point_x;
//         ray_origin_y = hit_point_y;
//         ray_origin_z = hit_point_z;

//         // diffuse reflection
//         float diffuese_x = curand_normal(&state);
//         float diffuese_y = curand_normal(&state);
//         float diffuese_z = curand_normal(&state);
//         const float norm = sqrt(diffuese_x * diffuese_x + diffuese_y * diffuese_y + diffuese_z * diffuese_z);
//         diffuese_x /= norm;
//         diffuese_y /= norm;
//         diffuese_z /= norm;
//         float dot = hit_face_normal_x * diffuese_x + hit_face_normal_y * diffuese_y + hit_face_normal_z * diffuese_z;
//         if (dot < 0.0f) {
//             diffuese_x = -diffuese_x;
//             diffuese_y = -diffuese_y;
//             diffuese_z = -diffuese_z;
//         }
//         ray_direction_x = diffuese_x;
//         ray_direction_y = diffuese_y;
//         ray_direction_z = diffuese_z;

//         float incoming_color_r = 0.0f;
//         float incoming_color_g = 0.0f;
//         float incoming_color_b = 0.0f;

//         compute_color(
//             face_vertices, object_types, num_faces, faces_stride,
//             current_path_depth + 1, max_path_depth,
//             ray_index, state,
//             ray_direction_x, ray_direction_y, ray_direction_z,
//             ray_origin_x, ray_origin_y, ray_origin_z,
//             incoming_color_r, incoming_color_g, incoming_color_b);

//         color_r = 0.8 * incoming_color_r;
//         color_g = 0.8 * incoming_color_g;
//         color_b = 0.8 * incoming_color_b;
//     }
// }

// __global__ void _render(
//     const float* rays,
//     const float* face_vertices,
//     const float* face_colors,
//     const int* object_types,
//     const int* material_types,
//     float* color_per_ray,
//     const int num_rays_per_thread,
//     const int num_rays,
//     const int num_faces,
//     const int faces_stride,
//     const int colors_stride,
//     const int max_path_depth)
// {
//     unsigned int tid = threadIdx.x;
//     curandStateXORWOW_t state;
//     curand_init(0, tid, 0, &state);

//     for (int n = 0; n < num_rays_per_thread; n++) {
//         unsigned int ray_index = (blockIdx.x * blockDim.x + threadIdx.x) * num_rays_per_thread + n;
//         if (ray_index >= num_rays) {
//             return;
//         }

//         const int p = ray_index * 7;
//         float ray_direction_x = rays[p + 0];
//         float ray_direction_y = rays[p + 1];
//         float ray_direction_z = rays[p + 2];
//         float ray_origin_x = rays[p + 3];
//         float ray_origin_y = rays[p + 4];
//         float ray_origin_z = rays[p + 5];

//         float color_r = 0.0;
//         float color_g = 0.0;
//         float color_b = 0.0;

//         int object_type = 0;
//         int material_type = 0;
//         float hit_point_x = 0.0f;
//         float hit_point_y = 0.0f;
//         float hit_point_z = 0.0f;
//         float hit_color_r = 0.0f;
//         float hit_color_g = 0.0f;
//         float hit_color_b = 0.0f;
//         float hit_face_normal_x = 0.0f;
//         float hit_face_normal_y = 0.0f;
//         float hit_face_normal_z = 0.0f;

//         color_r = 1.0f;
//         color_g = 1.0f;
//         color_b = 1.0f;

//         const float eps = 0.0000001;
//         float reflection_coeff = 1.0f;
//         bool did_hit_light = false;
//     }

// }

__global__ void render(
    const float* rays,
    const float* face_vertices,
    const float* face_colors,
    const int* object_types,
    const int* material_types,
    float* color_per_ray,
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

                if (object_type == RTX_CUDA_GEOMETRY_TYPE_STANDARD) {
                    const float va_x = shared_face_vertices[index + 0];
                    const float va_y = shared_face_vertices[index + 1];
                    const float va_z = shared_face_vertices[index + 2];
                    const float va_w = shared_face_vertices[index + 3];

                    const float vb_x = shared_face_vertices[index + 4];
                    const float vb_y = shared_face_vertices[index + 5];
                    const float vb_z = shared_face_vertices[index + 6];
                    const float vb_w = shared_face_vertices[index + 7];

                    const float vc_x = shared_face_vertices[index + 8];
                    const float vc_y = shared_face_vertices[index + 9];
                    const float vc_z = shared_face_vertices[index + 10];
                    const float vc_w = shared_face_vertices[index + 11];

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
                if (object_type == RTX_CUDA_GEOMETRY_TYPE_SPHERE) {
                    const float center_x = shared_face_vertices[index + 0];
                    const float center_y = shared_face_vertices[index + 1];
                    const float center_z = shared_face_vertices[index + 2];
                    const float center_w = shared_face_vertices[index + 3];
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
            }

            if (did_hit_object) {
                ray_origin_x = hit_point_x;
                ray_origin_y = hit_point_y;
                ray_origin_z = hit_point_z;

                if (material_type == 3) {
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

void rtx_cuda_alloc(
    float*& gpu_rays,
    float*& gpu_face_vertices,
    float*& gpu_face_colors,
    int*& gpu_object_types,
    int*& gpu_material_types,
    float*& gpu_color_per_ray,
    const float* rays,
    const float* face_vertices,
    const float* face_colors,
    const int* object_types,
    const int* material_types,
    const int num_rays,
    const int rays_stride,
    const int num_faces,
    const int faces_stride,
    const int colors_stride,
    const int num_pixels,
    const int num_rays_per_pixel)
{
    cudaMalloc((void**)&gpu_rays, sizeof(float) * num_rays * rays_stride);
    cudaMemcpy(gpu_rays, rays, sizeof(float) * num_rays * rays_stride, cudaMemcpyHostToDevice);

    cudaMalloc((void**)&gpu_face_vertices, sizeof(float) * num_faces * faces_stride);
    cudaMemcpy(gpu_face_vertices, face_vertices, sizeof(float) * num_faces * faces_stride, cudaMemcpyHostToDevice);

    cudaMalloc((void**)&gpu_face_colors, sizeof(float) * num_faces * colors_stride);
    cudaMemcpy(gpu_face_colors, face_colors, sizeof(float) * num_faces * colors_stride, cudaMemcpyHostToDevice);

    cudaMalloc((void**)&gpu_object_types, sizeof(int) * num_faces);
    cudaMemcpy(gpu_object_types, object_types, sizeof(int) * num_faces, cudaMemcpyHostToDevice);

    cudaMalloc((void**)&gpu_material_types, sizeof(int) * num_faces);
    cudaMemcpy(gpu_material_types, material_types, sizeof(int) * num_faces, cudaMemcpyHostToDevice);

    cudaMalloc((void**)&gpu_color_per_ray, sizeof(float) * num_pixels * 3 * num_rays_per_pixel);
}

void rtx_cuda_copy(
    float*& gpu_rays,
    float*& gpu_face_vertices,
    const float* rays,
    const float* face_vertices,
    const int num_rays,
    const int rays_stride,
    const int num_faces,
    const int faces_stride)
{
    cudaMemcpy(gpu_rays, rays, sizeof(float) * num_rays * rays_stride, cudaMemcpyHostToDevice);
    cudaMemcpy(gpu_face_vertices, face_vertices, sizeof(float) * num_faces * faces_stride, cudaMemcpyHostToDevice);
}

void rtx_cuda_delete(
    float*& gpu_rays,
    float*& gpu_face_vertices,
    float*& gpu_face_colors,
    int*& gpu_object_types,
    int*& gpu_material_types,
    float*& gpu_color_per_ray)
{
    cudaFree(gpu_rays);
    cudaFree(gpu_face_vertices);
    cudaFree(gpu_face_colors);
    cudaFree(gpu_object_types);
    cudaFree(gpu_material_types);
    cudaFree(gpu_color_per_ray);
}

void cuda_device_reset()
{
    cudaDeviceReset();
}

void rtx_cuda_ray_tracing_render(
    float*& gpu_rays,
    float*& gpu_face_vertices,
    float*& gpu_face_colors,
    int*& gpu_object_types,
    int*& gpu_material_types,
    float*& gpu_color_per_ray,
    float*& color_per_ray,
    const int num_rays,
    const int num_faces,
    const int faces_stride,
    const int colors_stride,
    const int path_depth,
    const int num_pixels,
    const int num_rays_per_pixel)
{
    assert(num_rays == num_pixels * num_rays_per_pixel);

    int num_threads = 128;
    int num_blocks = (num_rays - 1) / num_threads + 1;

    num_blocks = 512;

    int num_kernels = 1;
    assert(num_rays % num_kernels == 0);

    int num_rays_per_thread = num_rays / (num_threads * num_blocks * num_kernels) + 1;
    int num_rays_per_kernel = num_rays / num_kernels;

    // printf("rays: %d, rays_per_kernel: %d, num_rays_per_thread: %d\n", num_rays, num_rays_per_kernel, num_rays_per_thread);
    // printf("<<<%d, %d>>>\n", num_blocks, num_threads);

    int thread_offset = 0;
    for (int k = 0; k < num_kernels; k++) {
        render<<<num_blocks, num_threads>>>(
            gpu_rays,
            gpu_face_vertices,
            gpu_face_colors,
            gpu_object_types,
            gpu_material_types,
            gpu_color_per_ray,
            num_rays_per_thread,
            thread_offset,
            num_rays,
            num_faces,
            faces_stride,
            colors_stride,
            path_depth);
        thread_offset += num_rays_per_kernel;
    }
    cudaThreadSynchronize();

    // cudaDeviceProp dev;
    // cudaGetDeviceProperties(&dev, 0);

    // printf(" device name : %s\n", dev.name);
    // printf(" total global memory : %d (MB)\n", dev.totalGlobalMem/1024/1024);
    // printf(" shared memory / block : %d (KB)\n", dev.sharedMemPerBlock/1024);
    // printf(" register / block : %d\n", dev.regsPerBlock);

    cudaError_t status = cudaGetLastError();
    if (status != 0) {
        fprintf(stderr, "%s\n", cudaGetErrorString(status));
    }
    cudaMemcpy(color_per_ray, gpu_color_per_ray, sizeof(float) * num_pixels * 3 * num_rays_per_pixel, cudaMemcpyDeviceToHost);
}