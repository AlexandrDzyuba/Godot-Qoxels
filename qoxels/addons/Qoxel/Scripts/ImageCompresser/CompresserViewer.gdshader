shader_type canvas_item;
uniform sampler2D compressedtex : filter_nearest, repeat_disable;

#include "ImageCompresser.gdshaderinc"

uniform vec4 noise_offset = vec4(0, 0, 0, 0);
uniform float cube_size = 128.0;
uniform bool show_mask = false;

uniform int layer : hint_range(0, 127, 1)= 0;

vec2 get_line_atlas_uv(vec2 uv, int index, int count) {
    float size = 1.0 / float(count);
    return vec2(uv.x * size + float(index) * size, uv.y);
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	COLOR = texture(compressedtex, UV);//vec3(seamless_noise(vec4(UV * noise_offset.xy, noise_offset.zw)));
	if (show_mask){
		vec4 decompressed = texture(compressedtex, get_line_atlas_uv(UV, layer, 16));
		COLOR.rgb = vec3(decompressed.r);
		//COLOR.rgb = vec3(get_compressed(compressed.x).x);

		//vec4 z01m = get_compressed(compressed.x);
		//vec4 z23m = get_compressed(compressed.y);
		//vec4 z45m = get_compressed(compressed.z);
		//vec4 z67m = get_compressed(compressed.w);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
