#pragma once
#include "mesh.h"
#include <memory>
#include <vector>

namespace rtx {
class Scene {
private:
    bool _updated;

public:
    std::vector<std::shared_ptr<Mesh>> _mesh_array;
    void add(std::shared_ptr<Mesh> mesh);
    bool updated();
    void set_updated(bool updated);
    int num_triangles();
};
}