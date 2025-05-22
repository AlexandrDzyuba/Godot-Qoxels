const vec2 vec2MinusOne = vec2(-1, -1);
const vec2 vec2One = vec2(1, 1);

const vec2[8] dirmap_queue = {vec2(0, 1), vec2(-1, 1), vec2(1, 1), vec2(-1, 0), vec2(1, 0), vec2(-1, -1), vec2(1, -1), vec2(0, -1)};

const float e = 0.01;

const float borders_size = 2.0;
const float dither_factor = 1.0;
const float dither_offset = 1.5;

global uniform float TS;//65535.0;

vec2 pack_direction(vec2 dir){//0 = 1, 1 = 0, 2 = -1
	return vec2((2.0 - dir.x) -1.0, (2.0 - dir.y) -1.0) / TS;
}

vec2 unpack_direction(vec2 packed_dir){
	vec2 pdir = round(packed_dir * TS);
	return vec2(-(pdir.x - 2.0) -1.0, -(pdir.y - 2.0) -1.0);
}

int get_vec2_queue_idx(vec2 input){
	int idx = 0;
	input = sign(input);

	for (int i = 0; i < 8; i++){
		if (dirmap_queue[i] == input){
			return i;
		}
	}
	return idx;
}

vec2 get_pixel_uv(vec2 uv, vec2 pixel_size, vec2 scale){
	// Pixel uv
	vec2 rescaled_pixel_size = (pixel_size) * scale;
	vec2 pixel_zero = floor(uv / rescaled_pixel_size) * rescaled_pixel_size;
	vec2 pixel_uv = (uv - pixel_zero) / rescaled_pixel_size;
	return pixel_uv;
}

float random (vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}


// Функція для dithering
bool dither(vec2 uv, float dist) {
    // Розрахунок випадкового значення для dithering
   // float rand_val = fract(sin(dot(uv.xy ,vec2(12.9898, 78.233))) * 43758.5453);
   // float threshold = dither_factor;

    // Порівнюємо дистанцію до пікселя з порогом, що визначається випадковим значенням
    return false;//dither_offset - dist < threshold * rand_val;
}