#include "lambert.h"

namespace rtx {
MeshLambertMaterial::MeshLambertMaterial(pybind11::tuple color,
    float diffuse_reflectance)
{
    _color.r = color[0].cast<float>();
    _color.g = color[1].cast<float>();
    _color.b = color[2].cast<float>();
    _diffuse_reflectance = diffuse_reflectance;
}

MeshLambertMaterial::MeshLambertMaterial(float (&color)[3], float diffuse_reflectance)
{
    _color.r = color[0];
    _color.g = color[1];
    _color.b = color[2];
    _diffuse_reflectance = diffuse_reflectance;
}
glm::vec3f MeshLambertMaterial::reflect_color(glm::vec3f& input_color) const
{
    return _diffuse_reflectance * _color * input_color;
}
glm::vec3f MeshLambertMaterial::color() const
{
    return _color;
}
glm::vec3f MeshLambertMaterial::reflect_ray(glm::vec3f& diffuse_vec, glm::vec3f& specular_vec) const
{
    return diffuse_vec;
}
glm::vec3f MeshLambertMaterial::emit_color() const
{
    throw std::runtime_error("Not implemented");
};
int MeshLambertMaterial::type() const
{
    return RTX_MATERIAL_TYPE_LAMBERT;
}
}