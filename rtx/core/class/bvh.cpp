#include "bvh.h"
#include <algorithm>
#include <bitset>
#include <cassert>
#include <cfloat>
#include <iostream>
#include <utility>

namespace rtx {
using namespace bvh;
template <int L, typename T>
glm::vec3f merge_aabb_max(const glm::vec3f& a, const glm::vec<L, T>& b)
{
    glm::vec3f max;
    max.x = a.x > b.x ? a.x : b.x;
    max.y = a.y > b.y ? a.y : b.y;
    max.z = a.z > b.z ? a.z : b.z;
    return max;
}
template <int L, typename T>
glm::vec3f merge_aabb_min(const glm::vec3f& a, const glm::vec<L, T>& b)
{
    glm::vec3f min;
    min.x = a.x < b.x ? a.x : b.x;
    min.y = a.y < b.y ? a.y : b.y;
    min.z = a.z < b.z ? a.z : b.z;
    return min;
}
float compute_surface_area(const glm::vec3f max, const glm::vec3f min)
{
    float dx = max.x - min.x;
    float dy = max.y - min.y;
    float dz = max.z - min.z;
    return 2 * (dx * dy + dx * dz + dy * dz);
}

int detect_longest_axis(const glm::vec3f& axis_length)
{
    if (axis_length.x > axis_length.y) {
        if (axis_length.x > axis_length.z) {
            return RTX_AXIS_X;
        }
        return RTX_AXIS_Z;
    }
    if (axis_length.y > axis_length.x) {
        if (axis_length.y > axis_length.z) {
            return RTX_AXIS_Y;
        }
        return RTX_AXIS_Z;
    }
    if (axis_length.x > axis_length.z) {
        if (axis_length.y > axis_length.x) {
            return RTX_AXIS_Y;
        }
        return RTX_AXIS_X;
    }
    return RTX_AXIS_Z;
}
bool compare_position(const std::pair<int, float>& a, const std::pair<int, float>& b)
{
    return a.second < b.second;
}
Node::Node(std::vector<int> assigned_face_indices,
    std::shared_ptr<StandardGeometry>& geometry,
    int& current_index)
{
    // std::cout << "===================================" << std::endl;
    assert(assigned_face_indices.size() > 0);
    _assigned_face_indices = assigned_face_indices;
    _index = current_index;
    _is_leaf = false;
    // std::cout << "id: " << _index << std::endl;
    current_index++;
    _aabb_max = glm::vec3f(-FLT_MAX);
    _aabb_min = glm::vec3f(FLT_MAX);

    for (int face_index : assigned_face_indices) {
        auto& face = geometry->_face_vertex_indices_array.at(face_index);
        auto& va = geometry->_vertex_array[face[0]];
        _aabb_max = merge_aabb_max(_aabb_max, va);
        _aabb_min = merge_aabb_min(_aabb_min, va);

        auto& vb = geometry->_vertex_array[face[1]];
        _aabb_max = merge_aabb_max(_aabb_max, vb);
        _aabb_min = merge_aabb_min(_aabb_min, vb);

        auto& vc = geometry->_vertex_array[face[2]];
        _aabb_max = merge_aabb_max(_aabb_max, vc);
        _aabb_min = merge_aabb_min(_aabb_min, vc);
    }

    if (assigned_face_indices.size() <= geometry->bvh_max_triangles_per_node()) {
        _is_leaf = true;
        return;
    }
    const glm::vec3f axis_length = _aabb_max - _aabb_min;
    int longest_axis = detect_longest_axis(axis_length);
    // if (_index == 0) {
    //     longest_axis = RTX_AXIS_X;
    // }

    // std::cout << "longest: " << longest_axis << std::endl;
    std::vector<std::pair<int, float>> object_center_array;

    for (int face_index : assigned_face_indices) {
        auto& face = geometry->_face_vertex_indices_array.at(face_index);
        auto& va = geometry->_vertex_array[face[0]];
        auto& vb = geometry->_vertex_array[face[1]];
        auto& vc = geometry->_vertex_array[face[2]];
        auto center = (va + vb + vc) / 3.0f;
        if (longest_axis == RTX_AXIS_X) {
            object_center_array.emplace_back(face_index, center.x);
        } else if (longest_axis == RTX_AXIS_Y) {
            object_center_array.emplace_back(face_index, center.y);
        } else {
            object_center_array.emplace_back(face_index, center.z);
        }
    }

    std::sort(object_center_array.begin(), object_center_array.end(), compare_position);
    // std::cout << "sort:" << std::endl;
    // for (auto& pair : object_center_array) {
    //     std::cout << pair.first << ": " << pair.second << std::endl;
    // }
    float whole_surface_area = compute_surface_area(_aabb_max, _aabb_min);
    // std::cout << "whole_surface_area: " << whole_surface_area << std::endl;

    glm::vec3f volume_a_max(FLT_MAX);
    glm::vec3f volume_a_min(FLT_MAX);
    glm::vec3f volume_b_max(FLT_MAX);
    glm::vec3f volume_b_min(FLT_MAX);
    // std::cout << "==============================================================" << std::endl;

    float min_cost = FLT_MAX;
    int min_cost_split_index = 0;
    for (int split_index = 1; split_index <= object_center_array.size() - 1; split_index++) {
        int volume_a_num_faces = 0;
        int volume_b_num_faces = 0;
        for (int position = 0; position < split_index; position++) {
            int face_index = object_center_array[position].first;
            auto& face = geometry->_face_vertex_indices_array.at(face_index);

            glm::vec3f max = glm::vec3f(-FLT_MAX);
            glm::vec3f min = glm::vec3f(FLT_MAX);

            auto& va = geometry->_vertex_array[face[0]];
            max = merge_aabb_max(max, va);
            min = merge_aabb_min(min, va);

            auto& vb = geometry->_vertex_array[face[1]];
            max = merge_aabb_max(max, vb);
            min = merge_aabb_min(min, vb);

            auto& vc = geometry->_vertex_array[face[2]];
            max = merge_aabb_max(max, vc);
            min = merge_aabb_min(min, vc);

            // std::cout << "(left) object: " << object_index << ", max: " << max.x << ", " << max.y << ", " << max.z << " min: " << min.x << ", " << min.y << ", " << min.z << std::endl;
            // std::cout << "      volume max: " << volume_a_max.x << ", " << volume_a_max.y << ", " << volume_a_max.z << ", min: " << volume_b_min.x << ", " << volume_b_min.y << ", " << volume_b_min.z << std::endl;
            if (position == 0) {
                volume_a_max = max;
                volume_a_min = min;
            } else {
                volume_a_max = merge_aabb_max(volume_a_max, max);
                volume_a_min = merge_aabb_min(volume_a_min, min);
                // std::cout << "      merge: " << volume_a_max.x << ", " << volume_a_max.y << ", " << volume_a_max.z << ", min: " << volume_b_min.x << ", " << volume_b_min.y << ", " << volume_b_min.z << std::endl;
            }
            volume_a_num_faces += 1;
        }
        for (int position = split_index; position < object_center_array.size(); position++) {
            int face_index = object_center_array[position].first;
            auto& face = geometry->_face_vertex_indices_array.at(face_index);

            glm::vec3f max = glm::vec3f(-FLT_MAX);
            glm::vec3f min = glm::vec3f(FLT_MAX);

            auto& va = geometry->_vertex_array[face[0]];
            max = merge_aabb_max(max, va);
            min = merge_aabb_min(min, va);

            auto& vb = geometry->_vertex_array[face[1]];
            max = merge_aabb_max(max, vb);
            min = merge_aabb_min(min, vb);

            auto& vc = geometry->_vertex_array[face[2]];
            max = merge_aabb_max(max, vc);
            min = merge_aabb_min(min, vc);

            // std::cout << "(right) object: " << object_index << ", max: " << max.x << ", " << max.y << ", " << max.z << " min: " << min.x << ", " << min.y << ", " << min.z << std::endl;
            // std::cout << "      volume max: " << volume_a_max.x << ", " << volume_a_max.y << ", " << volume_a_max.z << ", min: " << volume_b_min.x << ", " << volume_b_min.y << ", " << volume_b_min.z << std::endl;
            if (position == split_index) {
                volume_b_max = max;
                volume_b_min = min;
            } else {
                volume_b_max = merge_aabb_max(volume_b_max, max);
                volume_b_min = merge_aabb_min(volume_b_min, min);
                // std::cout << "      merge: " << volume_b_max.x << ", " << volume_b_max.y << ", " << volume_b_max.z << ", min: " << volume_b_min.x << ", " << volume_b_min.y << ", " << volume_b_min.z << std::endl;
            }
            volume_b_num_faces += 1;
        }
        float surface_a = compute_surface_area(volume_a_max, volume_a_min);
        float surface_b = compute_surface_area(volume_b_max, volume_b_min);
        // std::cout << "split: " << split_index << ", surface_a: " << surface_a << ", surface_b: " << surface_b << std::endl;
        // std::cout << "split: " << split_index << ", faces_a: " << volume_a_num_faces << ", faces_b: " << volume_b_num_faces << std::endl;
        // std::cout << "split: " << split_index << ", a: " << (surface_a * volume_a_num_faces) << ", b: " << (surface_b * volume_b_num_faces) << std::endl;
        float cost = surface_a * volume_a_num_faces + surface_b * volume_b_num_faces;
        if (cost < min_cost) {
            min_cost = cost;
            min_cost_split_index = split_index;
        }
    }
    // std::cout << "min_cost: " << min_cost << std::endl;
    // std::cout << "min_cost_split_index: " << min_cost_split_index << std::endl;
    // throw std::runtime_error("");

    int split_index = min_cost_split_index;
    // std::cout << "split: " << split_index << std::endl;
    std::vector<int> left_assigned_indices;
    std::vector<int> right_assigned_indices;
    for (int n = 0; n < split_index; n++) {
        auto& pair = object_center_array.at(n);
        left_assigned_indices.push_back(pair.first);
    }
    for (int n = split_index; n < (int)assigned_face_indices.size(); n++) {
        auto& pair = object_center_array.at(n);
        right_assigned_indices.push_back(pair.first);
    }
    // std::cout << "left:" << std::endl;
    // for (auto index : left_assigned_indices) {
    //     std::cout << index << std::endl;
    // }
    // std::cout << "right:" << std::endl;
    // for (auto index : right_assigned_indices) {
    //     std::cout << index << std::endl;
    // }
    _left = std::make_shared<Node>(left_assigned_indices, geometry, current_index);
    _right = std::make_shared<Node>(right_assigned_indices, geometry, current_index);
}
void Node::set_hit_and_miss_links()
{
    if (_left) {
        _hit = _left;
        if (_right) {
            _left->_miss = _right;
        } else {
            _left->_miss = _miss;
        }
        _left->set_hit_and_miss_links();
    }
    if (_right) {
        _right->_miss = _miss;
        _right->set_hit_and_miss_links();
    }
}
int Node::num_children()
{
    int num_children = 0;
    if (_left) {
        num_children += _left->num_children() + 1;
    }
    if (_right) {
        num_children += _right->num_children() + 1;
    }
    return num_children;
}
void Node::collect_children(std::vector<std::shared_ptr<Node>>& children)
{
    if (_left) {
        children.push_back(_left);
        _left->collect_children(children);
    }
    if (_right) {
        children.push_back(_right);
        _right->collect_children(children);
    }
}
BVH::BVH(std::shared_ptr<StandardGeometry>& geometry)
{
    std::vector<int> assigned_face_indices;
    for (int face_index = 0; face_index < (int)geometry->_face_vertex_indices_array.size(); face_index++) {
        assigned_face_indices.push_back(face_index);
    }
    _node_current_index = 0;
    _root = std::make_shared<Node>(assigned_face_indices, geometry, _node_current_index);
    _root->set_hit_and_miss_links();

    _num_nodes = _root->num_children() + 1;
}
int BVH::num_nodes()
{
    return _num_nodes;
}
void BVH::serialize(rtx::array<int>& node_buffer, rtx::array<float>& aabb_buffer, int offset)
{
    std::vector<std::shared_ptr<Node>> children = { _root };
    _root->collect_children(children);
    int face_indices_start = 0;
    int face_indices_end = 0;
    for (auto& node : children) {
        int j = node->_index + offset;

        if(node->_is_leaf){
            face_indices_end += node->_assigned_face_indices.size() - 1;
        }

        node_buffer[j * 4 + 0] = node->_hit ? node->_hit->_index : -1;
        node_buffer[j * 4 + 1] = node->_miss ? node->_miss->_index : -1;
        node_buffer[j * 4 + 2] = face_indices_start;
        node_buffer[j * 4 + 3] = face_indices_end;

        aabb_buffer[j * 8 + 0] = node->_aabb_max.x;
        aabb_buffer[j * 8 + 1] = node->_aabb_max.y;
        aabb_buffer[j * 8 + 2] = node->_aabb_max.z;
        aabb_buffer[j * 8 + 3] = 1.0f;
        aabb_buffer[j * 8 + 4] = node->_aabb_min.x;
        aabb_buffer[j * 8 + 5] = node->_aabb_min.y;
        aabb_buffer[j * 8 + 6] = node->_aabb_min.z;
        aabb_buffer[j * 8 + 7] = 1.0f;

        printf("node: %d face_start: %d face_end: %d max: (%f, %f, %f) min: (%f, %f, %f)\n", node->_index, face_indices_start, face_indices_end, node->_aabb_max.x, node->_aabb_max.y, node->_aabb_max.z, node->_aabb_min.x, node->_aabb_min.y, node->_aabb_min.z);
        printf("    hit: %d miss: %d left: %d right: %d\n", (node->_hit ? node->_hit->_index : -1), (node->_miss ? node->_miss->_index : -1), (node->_left ? node->_left->_index : -1), (node->_right ? node->_right->_index : -1));

        if(node->_is_leaf){
            face_indices_start += node->_assigned_face_indices.size();
        }
    }
}
}