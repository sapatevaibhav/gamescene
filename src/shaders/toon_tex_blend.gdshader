// Soft see-through variant for imported characters: eyelashes, eyebrows,
// eye highlights and other painted overlays that blend over the face.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;
#define TOON_BLEND
#include "res://src/shaders/toon_tex.gdshaderinc"
