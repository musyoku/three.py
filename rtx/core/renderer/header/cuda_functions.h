#pragma once

#define rtx_cuda_kernel_intersect_triangle_or_continue(va, vb, vc, s, t, min_distance) \
    {                                                                                  \
        const float eps = 0.000001;                                                    \
        float3 edge_ba = {                                                             \
            vb.x - va.x,                                                               \
            vb.y - va.y,                                                               \
            vb.z - va.z,                                                               \
        };                                                                             \
        float3 edge_ca = {                                                             \
            vc.x - va.x,                                                               \
            vc.y - va.y,                                                               \
            vc.z - va.z,                                                               \
        };                                                                             \
        float3 h = {                                                                   \
            ray.direction.y * edge_ca.z - ray.direction.z * edge_ca.y,                 \
            ray.direction.z * edge_ca.x - ray.direction.x * edge_ca.z,                 \
            ray.direction.x * edge_ca.y - ray.direction.y * edge_ca.x,                 \
        };                                                                             \
        float f = edge_ba.x * h.x + edge_ba.y * h.y + edge_ba.z * h.z;                 \
        if (f > -eps && f < eps) {                                                     \
            continue;                                                                  \
        }                                                                              \
        f = 1.0f / f;                                                                  \
        s.x = ray.origin.x - va.x;                                                     \
        s.y = ray.origin.y - va.y;                                                     \
        s.z = ray.origin.z - va.z;                                                     \
        float dot = s.x * h.x + s.y * h.y + s.z * h.z;                                 \
        float u = f * dot;                                                             \
        if (u < 0.0f || u > 1.0f) {                                                    \
            continue;                                                                  \
        }                                                                              \
        h.x = s.y * edge_ba.z - s.z * edge_ba.y;                                       \
        h.y = s.z * edge_ba.x - s.x * edge_ba.z;                                       \
        h.z = s.x * edge_ba.y - s.y * edge_ba.x;                                       \
        dot = h.x * ray.direction.x + h.y * ray.direction.y + h.z * ray.direction.z;   \
        float v = f * dot;                                                             \
        if (v < 0.0f || u + v > 1.0f) {                                                \
            continue;                                                                  \
        }                                                                              \
        s.x = edge_ba.y * edge_ca.z - edge_ba.z * edge_ca.y;                           \
        s.y = edge_ba.z * edge_ca.x - edge_ba.x * edge_ca.z;                           \
        s.z = edge_ba.x * edge_ca.y - edge_ba.y * edge_ca.x;                           \
        float norm = sqrtf(s.x * s.x + s.y * s.y + s.z * s.z) + 1e-12;                 \
        s.x = s.x / norm;                                                              \
        s.y = s.y / norm;                                                              \
        s.z = s.z / norm;                                                              \
        dot = s.x * ray.direction.x + s.y * ray.direction.y + s.z * ray.direction.z;   \
        if (dot > 0.0f) {                                                              \
            continue;                                                                  \
        }                                                                              \
        dot = edge_ca.x * h.x + edge_ca.y * h.y + edge_ca.z * h.z;                     \
        t = f * dot;                                                                   \
        if (t <= 0.001f) {                                                             \
            continue;                                                                  \
        }                                                                              \
        if (min_distance <= t) {                                                       \
            continue;                                                                  \
        }                                                                              \
    }

#define rtx_cuda_kernel_intersect_sphere_or_continue(center, radius, t, min_distance)                                              \
    {                                                                                                                              \
        float4 oc = {                                                                                                              \
            ray.origin.x - center.x,                                                                                               \
            ray.origin.y - center.y,                                                                                               \
            ray.origin.z - center.z,                                                                                               \
        };                                                                                                                         \
        const float a = ray.direction.x * ray.direction.x + ray.direction.y * ray.direction.y + ray.direction.z * ray.direction.z; \
        const float b = 2.0f * (ray.direction.x * oc.x + ray.direction.y * oc.y + ray.direction.z * oc.z);                         \
        const float c = (oc.x * oc.x + oc.y * oc.y + oc.z * oc.z) - radius.x * radius.x;                                           \
        const float d = b * b - 4.0f * a * c;                                                                                      \
        if (d <= 0) {                                                                                                              \
            continue;                                                                                                              \
        }                                                                                                                          \
        const float root = sqrt(d);                                                                                                \
        t = (-b - root) / (2.0f * a);                                                                                              \
        if (t <= 0.001f) {                                                                                                         \
            t = (-b + root) / (2.0f * a);                                                                                          \
            if (t <= 0.001f) {                                                                                                     \
                continue;                                                                                                          \
            }                                                                                                                      \
        }                                                                                                                          \
        if (min_distance <= t) {                                                                                                   \
            continue;                                                                                                              \
        }                                                                                                                          \
    }

#define rtx_cuda_kernel_bvh_traversal_one_step_or_continue(node, ray_direction_inv, bvh_current_node_index)                    \
    {                                                                                                                          \
        float tmin = ((ray_direction_inv.x < 0 ? node.aabb_max.x : node.aabb_min.x) - ray.origin.x) * ray_direction_inv.x;     \
        float tmax = ((ray_direction_inv.x < 0 ? node.aabb_min.x : node.aabb_max.x) - ray.origin.x) * ray_direction_inv.x;     \
        float tmp_tmin = ((ray_direction_inv.y < 0 ? node.aabb_max.y : node.aabb_min.y) - ray.origin.y) * ray_direction_inv.y; \
        float tmp_tmax = ((ray_direction_inv.y < 0 ? node.aabb_min.y : node.aabb_max.y) - ray.origin.y) * ray_direction_inv.y; \
        if ((tmin > tmp_tmax) || (tmp_tmin > tmax)) {                                                                          \
            bvh_current_node_index = node.miss_node_index;                                                                     \
            continue;                                                                                                          \
        }                                                                                                                      \
        if (tmp_tmin > tmin) {                                                                                                 \
            tmin = tmp_tmin;                                                                                                   \
        }                                                                                                                      \
        if (tmp_tmax < tmax) {                                                                                                 \
            tmax = tmp_tmax;                                                                                                   \
        }                                                                                                                      \
        tmp_tmin = ((ray_direction_inv.z < 0 ? node.aabb_max.z : node.aabb_min.z) - ray.origin.z) * ray_direction_inv.z;       \
        tmp_tmax = ((ray_direction_inv.z < 0 ? node.aabb_min.z : node.aabb_max.z) - ray.origin.z) * ray_direction_inv.z;       \
        if ((tmin > tmp_tmax) || (tmp_tmin > tmax)) {                                                                          \
            bvh_current_node_index = node.miss_node_index;                                                                     \
            continue;                                                                                                          \
        }                                                                                                                      \
        if (tmp_tmin > tmin) {                                                                                                 \
            tmin = tmp_tmin;                                                                                                   \
        }                                                                                                                      \
        if (tmp_tmax < tmax) {                                                                                                 \
            tmax = tmp_tmax;                                                                                                   \
        }                                                                                                                      \
        /* 計算誤差を防ぐ */                                                                                            \
        if (tmax < 0.001) {                                                                                                    \
            bvh_current_node_index = node.miss_node_index;                                                                     \
            continue;                                                                                                          \
        }                                                                                                                      \
    }

#define rtx_cuda_kernel_fetch_hit_color(hit_object, hit_color, texture_object_array)                                                                                                                       \
    {                                                                                                                                                                                                      \
        int material_type = hit_object.layerd_material_types.outside;                                                                                                                                      \
        int mapping_type = hit_object.mapping_type;                                                                                                                                                        \
        int geometry_type = hit_object.geometry_type;                                                                                                                                                      \
        if (mapping_type == RTXMappingTypeSolidColor) {                                                                                                                                                    \
            rtxRGBAColor color = shared_serialized_color_mapping_array[hit_object.mapping_index];                                                                                                          \
            hit_color.r = color.r;                                                                                                                                                                         \
            hit_color.g = color.g;                                                                                                                                                                         \
            hit_color.b = color.b;                                                                                                                                                                         \
        } else if (mapping_type == RTXMappingTypeTexture) {                                                                                                                                                \
            if (geometry_type == RTXGeometryTypeStandard) {                                                                                                                                                \
                /* 衝突位置を重心座標系で表す */                                                                                                                                              \
                /* https://shikihuiku.wordpress.com/2017/05/23/barycentric-coordinates%E3%81%AE%E8%A8%88%E7%AE%97%E3%81%A8perspective-correction-partial-derivative%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6/*/ \
                float3 d1 = { hit_va.x - hit_vc.x, hit_va.y - hit_vc.y, hit_va.z - hit_vc.z };                                                                                                             \
                float3 d2 = { hit_vb.x - hit_vc.x, hit_vb.y - hit_vc.y, hit_vb.z - hit_vc.z };                                                                                                             \
                float3 d = { hit_point.x - hit_vc.x, hit_point.y - hit_vc.y, hit_point.z - hit_vc.z };                                                                                                     \
                float d1x = d1.x * d1.x + d1.y * d1.y + d1.z * d1.z;                                                                                                                                       \
                float d1y = d1.x * d2.x + d1.y * d2.y + d1.z * d2.z;                                                                                                                                       \
                float d2x = d1y;                                                                                                                                                                           \
                float d2y = d2.x * d2.x + d2.y * d2.y + d2.z * d2.z;                                                                                                                                       \
                float dx = d.x * d1.x + d.y * d1.y + d.z * d1.z;                                                                                                                                           \
                float dy = d.x * d2.x + d.y * d2.y + d.z * d2.z;                                                                                                                                           \
                float det = d1x * d2y - d1y * d2x;                                                                                                                                                         \
                float3 lambda = { (dx * d2y - dy * d2x) / det, (d1x * dy - d1y * dx) / det, 0.0f };                                                                                                        \
                lambda.z = 1.0f - lambda.x - lambda.y;                                                                                                                                                     \
                const float2 uv_a = tex1Dfetch(g_serialized_uv_coordinate_array_texture_ref, hit_face.x + hit_object.serialized_uv_coordinates_offset);                                                    \
                const float2 uv_b = tex1Dfetch(g_serialized_uv_coordinate_array_texture_ref, hit_face.y + hit_object.serialized_uv_coordinates_offset);                                                    \
                const float2 uv_c = tex1Dfetch(g_serialized_uv_coordinate_array_texture_ref, hit_face.z + hit_object.serialized_uv_coordinates_offset);                                                    \
                float x = max(0.0f, lambda.x * uv_a.x + lambda.y * uv_b.x + lambda.z * uv_c.x);                                                                                                            \
                float y = max(0.0f, lambda.x * uv_a.y + lambda.y * uv_b.y + lambda.z * uv_c.y);                                                                                                            \
                float4 color = tex2D<float4>(texture_object_array[hit_object.mapping_index], x, y);                                                                                                        \
                hit_color.r = color.x;                                                                                                                                                                     \
                hit_color.g = color.y;                                                                                                                                                                     \
                hit_color.b = color.z;                                                                                                                                                                     \
            } else {                                                                                                                                                                                       \
                hit_color.r = 0.0f;                                                                                                                                                                        \
                hit_color.g = 0.0f;                                                                                                                                                                        \
                hit_color.b = 0.0f;                                                                                                                                                                        \
            }                                                                                                                                                                                              \
        }                                                                                                                                                                                                  \
        if (material_type == RTXMaterialTypeLambert) {                                                                                                                                                     \
            rtxLambertMaterialAttribute attr = ((rtxLambertMaterialAttribute*)&shared_serialized_material_attribute_byte_array[hit_object.material_attribute_byte_array_offset])[0];                       \
            hit_color.r *= attr.albedo;                                                                                                                                                                    \
            hit_color.g *= attr.albedo;                                                                                                                                                                    \
            hit_color.b *= attr.albedo;                                                                                                                                                                    \
        } else if (material_type == RTXMaterialTypeEmissive) {                                                                                                                                             \
            rtxEmissiveMaterialAttribute attr = ((rtxEmissiveMaterialAttribute*)&shared_serialized_material_attribute_byte_array[hit_object.material_attribute_byte_array_offset])[0];                     \
            did_hit_light = true;                                                                                                                                                                          \
            hit_color.r *= attr.brightness;                                                                                                                                                                \
            hit_color.g *= attr.brightness;                                                                                                                                                                \
            hit_color.b *= attr.brightness;                                                                                                                                                                \
        }                                                                                                                                                                                                  \
    }

#define rtx_cuda_kernel_update_ray_direction(ray, hit_point, hit_face_normal, path_weight, curand_state)                                  \
    {                                                                                                                                     \
        float4 path = {                                                                                                                   \
            hit_point.x - ray.origin.x,                                                                                                   \
            hit_point.y - ray.origin.y,                                                                                                   \
            hit_point.z - ray.origin.z,                                                                                                   \
        };                                                                                                                                \
        float distance = sqrt(path.x * path.x + path.y * path.y + path.z * path.z);                                                       \
        ray.origin.x = hit_point.x;                                                                                                       \
        ray.origin.y = hit_point.y;                                                                                                       \
        ray.origin.z = hit_point.z;                                                                                                       \
        float3 unit_diffuse = {                                                                                                           \
            curand_normal(&curand_state),                                                                                                 \
            curand_normal(&curand_state),                                                                                                 \
            curand_normal(&curand_state),                                                                                                 \
        };                                                                                                                                \
        float norm = sqrt(unit_diffuse.x * unit_diffuse.x + unit_diffuse.y * unit_diffuse.y + unit_diffuse.z * unit_diffuse.z);           \
        unit_diffuse.x /= norm;                                                                                                           \
        unit_diffuse.y /= norm;                                                                                                           \
        unit_diffuse.z /= norm;                                                                                                           \
        float cosine_term = hit_face_normal.x * unit_diffuse.x + hit_face_normal.y * unit_diffuse.y + hit_face_normal.z * unit_diffuse.z; \
        if (cosine_term < 0.0f) {                                                                                                         \
            unit_diffuse.x *= -1;                                                                                                         \
            unit_diffuse.y *= -1;                                                                                                         \
            unit_diffuse.z *= -1;                                                                                                         \
            cosine_term *= -1;                                                                                                            \
        }                                                                                                                                 \
        ray.direction.x = unit_diffuse.x;                                                                                                 \
        ray.direction.y = unit_diffuse.y;                                                                                                 \
        ray.direction.z = unit_diffuse.z;                                                                                                 \
        ray_direction_inv.x = 1.0f / ray.direction.x;                                                                                     \
        ray_direction_inv.y = 1.0f / ray.direction.y;                                                                                     \
        ray_direction_inv.z = 1.0f / ray.direction.z;                                                                                     \
        path_weight.r *= 4.0 * hit_color.r * cosine_term;                                                                                 \
        path_weight.g *= 4.0 * hit_color.g * cosine_term;                                                                                 \
        path_weight.b *= 4.0 * hit_color.b * cosine_term;                                                                                 \
    };

#define rtx_cuda_check_kernel_arguments()                                  \
    {                                                                      \
        assert(gpu_serialized_ray_array != NULL);                          \
        assert(gpu_serialized_face_vertex_index_array != NULL);            \
        assert(gpu_serialized_vertex_array != NULL);                       \
        assert(gpu_serialized_object_array != NULL);                       \
        assert(gpu_serialized_material_attribute_byte_array != NULL);      \
        assert(gpu_serialized_threaded_bvh_array != NULL);                 \
        assert(gpu_serialized_threaded_bvh_node_array != NULL);            \
        assert(gpu_serialized_render_array != NULL);                       \
        if (color_mapping_array_size > 0) {                                \
            assert(gpu_serialized_color_mapping_array != NULL);            \
        }                                                                  \
        if (uv_coordinate_array_size > 0) {                                \
            assert(gpu_serialized_serialized_uv_coordinate_array != NULL); \
        }                                                                  \
    }