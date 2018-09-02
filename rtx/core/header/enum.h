#pragma once

enum RTX_AXIS {
    RTX_AXIS_X = 1,
    RTX_AXIS_Y,
    RTX_AXIS_Z,
};

enum RTX_MATERIAL_TYPE {
    RTX_MATERIAL_TYPE_LAMBERT = 1,
    RTX_MATERIAL_TYPE_METAL,
    RTX_MATERIAL_TYPE_EMISSIVE,
};

enum RTX_GEOMETRY_TYPE {
    RTX_GEOMETRY_TYPE_STANDARD = 1,
    RTX_GEOMETRY_TYPE_SPHERE,
};

enum RTX_CAMERA_TYPE {
    RTX_CAMERA_TYPE_PERSPECTIVE = 1,
    RTX_CAMERA_TYPE_ORTHOGONAL,
};

#define SCENE_BVH_TERMINAL_NODE 255
#define SCENE_BVH_INNER_NODE 255