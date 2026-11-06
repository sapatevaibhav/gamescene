// Cel-shaded terrain (anime style).
shader_type spatial;
render_mode diffuse_toon, specular_toon;
#define TOON
#include "res://src/shaders/terrain_common.gdshaderinc"
