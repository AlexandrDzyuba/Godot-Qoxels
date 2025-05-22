shader_type spatial;

#include "GWD.gdshaderinc"
#include "res://addons/Qoxel/Scripts/ImageCompresser/ImageCompresser.gdshaderinc"

render_mode cull_disabled;

uniform sampler3D world_mask : filter_nearest, repeat_disable;
uniform sampler2D compressed_tex : filter_nearest, repeat_disable;

uniform vec3 world_size = vec3(128.0, 128.0, 128.0);
uniform float detail_level = 3.0;
uniform float skip_level : hint_range(0.0, 1024.0, 1) = 0.0;
global uniform float erase_level : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float label_slider : hint_range(0.0, 1.0, 0.001) = 0.0;

uniform sampler2DArray tileset : filter_nearest;
uniform vec4 atlas_size = vec4(6.0, 33.0, 64.0, 64.0);

uniform sampler2DArray tileset_normalmap : filter_nearest;
uniform float normal = 0.25;

group_uniforms culling;

uniform sampler3D texture3d : filter_nearest;
uniform float start_distance = 32.0; // Дистанція, з якої починається dither
uniform float max_distance = 64.0; // Максимальна дистанція для повного зникнення
const float angle_threshold = 0.5; // Поріг кулінгу (чим ближче до -1, тим більше квадів зберігаються)
const float dither_intensity = 1.0; // Інтенсивність dither (0-1)

varying float ax;
varying float ls;
varying vec2 OUV;
varying vec2 front_face_uv;
varying vec2 front_face_uv2;
varying vec3 vert;
varying float is_loded;


vec2 get_line_atlas_uv(vec2 uv, int index, int count) {
    float size = 1.0 / float(count);
    return vec2(uv.x * size + float(index) * size, uv.y);
}

void vertex(){// REQUIRE SUB VOXELS OPTIMIZATION (Discard quads)
	vert = VERTEX;
	// Faces setuping (to handle the each face correctly)
	OUV = UV;
	ax = (COLOR.r * 3.0) + 0.1;
	int axis = int((ax));
	
	ls = e / world_size[axis];
	
	
	int quad_idx = int(CUSTOM0.r);
	
	vec3 center_of_node = (NODE_POSITION_WORLD + (world_size/2.0));
	float dist = distance(CAMERA_POSITION_WORLD, center_of_node);
	is_loded = 0.0;
	if (false) {
		if (dist > start_distance){
			if ( quad_idx % int(detail_level) != 0){
				VERTEX += vec3(1000000.0);
			}
			if (dist > max_distance)
				is_loded = 1.0;
		}
	}
	
	if (axis == 0){// X - Axis
		vec2 uv = vec2(UV2.x + ls, UV.x);
		vec2 uv2 = vec2(1.0-UV.y);

		UV = uv;
		UV2 = uv2;

		front_face_uv = uv;
		front_face_uv2 = uv2;
		front_face_uv.x -= ls;
	}else if (axis == 1){// Y - Axis
		vec2 uv = vec2(UV);
		vec2 uv2 = vec2(UV2);

		UV = uv;
		UV2 = uv2;

		front_face_uv = uv;
		front_face_uv2 = uv2;
		front_face_uv2.x -= ls;
	}else{// Z - Axis
		vec2 uv = vec2(UV.x, UV2.x);
		vec2 uv2 = vec2(1.0-UV.y);

		UV = uv;
		UV2 = uv2;

		front_face_uv = uv;
		front_face_uv2 = uv2;
		front_face_uv.y += ls;
	}
}

void fragment() {
	// REQUIRE FIX FOR CHUNK BORDER and SUB VOXELS BORDERS

	float distance_to_camera = length(CAMERA_POSITION_WORLD - vert);



	// Voxel shader
	vec2 uv = vec2(UV);
	vec2 uv2 = vec2(UV2);

	int axis = int(ax);

	if (FRONT_FACING){
		uv = front_face_uv;
		uv2 = front_face_uv2;

		if (uv.x <= 0.0 || uv.y <= 0.0){
			discard;
		}
	}
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	uv2 = clamp(uv2, vec2(0.0), vec2(1.0));

	float level = floor(clamp(uv2.x * world_size[axis] + ls, 0.0, 1.0)) / world_size[axis];
	
	float levelr = floor(uv2.x * world_size[axis] + ls);
	float voxel_local_level = fract(uv2.x);

	if (levelr >= world_size[axis] || skip_level > levelr){
		discard;
	}

	// Getting world position
	vec3 qoxel = vec3(uv.x, 1.0-level, uv.y) * world_size;
	vec3 qoxel_global_position = (NODE_POSITION_WORLD - world_size/2.0) + qoxel;
	// Getting depth distance
	float dist = distance(CAMERA_POSITION_WORLD, qoxel_global_position) / length(world_size);

	vec2 ruv = floor((uv * world_size.xy) - ls) / world_size.xy;
	
	float L = (levelr - 1.0);
	
	
	//vec4 world = round(texture(world_mask, vec3(ruv, levelr/world_size[axis])) * 8191.0);
	vec4 decompressed = texture(compressed_tex, get_line_atlas_uv(ruv, int(levelr), int(world_size[axis])));
	vec4 world = vec4(decompressed.x);


	if (erase_level > world.r / 8191.0){
		discard;
	}


	// Tileset texture
	float tid = (world.r);
	tid = clamp( round(abs(fract(tid / 14.0)) * 14.0), 1.0, 14.0);

	float TID_offset = 0.0;
	vec2 TOUV = OUV;

	if (axis == 1){
		TID_offset = FRONT_FACING ? 4.0 : 0.0;
	}else{
		TID_offset = 2.0;
		TOUV = vec2(1.0-OUV.x, 1.0-OUV.y);
	}

	float TID_ALBEDO = (tid * atlas_size.x) + TID_offset;
	float TID_NORMAL = TID_ALBEDO + 1.0;

	vec2 tileset_uv = vec2(TOUV.x, TOUV.y) * world_size.xy;
	//vec2 tuvf = fract(tileset_uv);

	vec4 ttex = texture(tileset, vec3(tileset_uv, TID_ALBEDO));
	vec4 ntex = texture(tileset, vec3(tileset_uv, TID_NORMAL));

	vec4 name = texture(tileset, vec3(tileset_uv, TID_offset));

	// Raymarching
	ALBEDO = mix(ttex.rgb, name.rgb, name.a * label_slider);
	NORMAL_MAP = ntex.rgb;
	NORMAL_MAP_DEPTH = normal;
	
	if (is_loded <= 0.0){
		float oe = (1.0/VIEWPORT_SIZE).y;
		vec3 drv = (vec3(uv, voxel_local_level) * world_size);
		vec4 detail_texture = texture(texture3d, vec3(drv.xy - ls, drv.z + ls) );
		if (detail_texture.a <= 0.)
			discard;
		//ALBEDO = detail_texture.xyz;
	}

}
