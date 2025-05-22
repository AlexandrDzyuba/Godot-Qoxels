shader_type canvas_item;

uniform sampler2D input : filter_nearest;
uniform vec2 input_size = vec2(128, 8);
uniform int layers = 8;

vec2 get_line_atlas_uv(vec2 uv, int index, int count) {
    float size = 1.0 / float(count);
    return vec2(uv.x * size + float(index) * size, uv.y);
}

int get_layer(vec2 uv){
	return int(uv.x * input_size.x) / layers;
}

void fragment() {
	vec2 uv = floor(UV * input_size) / input_size;
	int Z = get_layer(UV);
	vec4 CURR = texture(input, UV);

	COLOR = CURR;

	if (Z < layers && Z > 0){
		if (CURR.x > 0.0){
			vec4 BOTTOM = texture(input, get_line_atlas_uv(UV, Z + 1, layers));
			if (BOTTOM.x <= 0.0){
				COLOR = vec4(0,0,0,1);
			}
		}else{
			if (Z + 1 < layers){
				vec4 TOP = texture(input, get_line_atlas_uv(UV, Z - 1, layers));
				if (TOP.r > 0.0){
					COLOR = TOP;
				}
			}
		}



	}
}
