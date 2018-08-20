#pragma once
#include "../../class/material.h"
#include <glm/glm.hpp>
#include <pybind11/pybind11.h>

namespace rtx {
class MeshEmissiveMaterial : public Material {
private:
    glm::vec3 _color;

public:
    // color: [0, 1]
    MeshEmissiveMaterial(pybind11::tuple color);
    MeshEmissiveMaterial(float (&color)[3]);
    glm::vec3 reflect_color(glm::vec3& input_color) const override;
    glm::vec3 reflect_ray(glm::vec3& diffuse_vec, glm::vec3& specular_vec) const override;
    glm::vec3 emit_color() const override;
    MaterialType type() const override;
};
}