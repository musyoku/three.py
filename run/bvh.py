import math
import time
import numpy as np
import rtx
import geometry as gm
import matplotlib.pyplot as plt

scene = rtx.Scene()

box_size = 6

# ceil
geometry = rtx.PlainGeometry(box_size, box_size)
material = rtx.MeshLambertMaterial((1.0, 1.0, 1.0), 1.0)
ceil = rtx.Mesh(geometry, material)
ceil.set_rotation((math.pi / 2, 0, 0))
ceil.set_position((0, box_size / 2, 0))
scene.add(ceil)

# floor
geometry = rtx.PlainGeometry(box_size, box_size)
material = rtx.MeshLambertMaterial((1.0, 1.0, 1.0), 1.0)
floor = rtx.Mesh(geometry, material)
floor.set_rotation((-math.pi / 2, 0, 0))
floor.set_position((0, -box_size / 2, 0))
scene.add(floor)

# place bunny
faces, vertices = gm.load("bunny")
geometry = rtx.StandardGeometry(faces, vertices, 500)
material = rtx.MeshLambertMaterial(
    color=(1.0, 1.0, 1.0), diffuse_reflectance=1.0)
bunny = rtx.Mesh(geometry, material)
bunny.set_scale((3, 3, 3))
scene.add(bunny)

screen_width = 512
screen_height = 512

render_options = rtx.RayTracingOptions()
render_options.num_rays_per_pixel = 32
render_options.max_bounce = 5

renderer = rtx.RayTracingCUDARenderer()
camera = rtx.PerspectiveCamera(
    eye=(0, 0, -1),
    center=(0, 0, 0),
    up=(0, 1, 0),
    fov_rad=math.pi / 3,
    aspect_ratio=screen_width / screen_height,
    z_near=0.01,
    z_far=100)

render_buffer = np.zeros((screen_height, screen_width, 3), dtype="float32")
# renderer.render(scene, camera, render_options, render_buffer)
camera_rad = 0
# camera_rad = math.pi / 10 * 2
radius = 5.5
start = time.time()
total_iterations = 100
for n in range(total_iterations):
    eye = (radius * math.sin(camera_rad), 0.0, radius * math.cos(camera_rad))
    camera.look_at(eye=eye, center=(0, 0, 0), up=(0, 1, 0))

    renderer.render(scene, camera, render_options, render_buffer)
    # linear -> sRGB
    pixels = np.power(np.clip(render_buffer, 0, 1), 1.0 / 2.2)
    # display
    plt.imshow(pixels, interpolation="none")
    plt.pause(1e-8)

    camera_rad += math.pi / 10
    exit()

end = time.time()
print(total_iterations / (end - start))