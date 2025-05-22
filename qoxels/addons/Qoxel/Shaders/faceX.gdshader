shader_type spatial;

#include "GWD.gdshaderinc"

render_mode cull_disabled;
uniform sampler3D world_mask : filter_nearest;
uniform sampler2D tex : repeat_enable;

uniform vec3 world_size = vec3(128.0, 128.0, 128.0);
uniform float skil_level : hint_range(0.0, 1024.0, 1) = 0.0;
uniform float erase_level : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform sampler2DArray tileset : filter_nearest;
uniform sampler2DArray tileset_normalmap : filter_nearest;
uniform float normal = 0.25;

uniform bool show_uv = false;

void fragment() {
	vec3 ws = world_size + vec3(0.0, 0.0, 0.0);

	float ls = e / ws.x;

	vec2 uv = vec2(UV2.x + ls, UV.x);
	vec2 uv2 = vec2(1.0 - UV.y);

	if (FRONT_FACING){
		uv = vec2(UV2.x, UV.x);
		uv2 = vec2(1.0 - UV.y);
		uv.x -= ls;
	}

	float level = floor(uv2.x * ws.x) / ws.x;
	float levelr = floor(uv2.x * ws.x);

	// Getting world position
	vec3 qoxel = vec3(uv.x, 1.0-level, uv.y) * world_size;
	vec3 qoxel_global_position = (NODE_POSITION_WORLD - world_size/2.0) + qoxel;
	// Getting depth distance
	float dist = distance(CAMERA_POSITION_WORLD, qoxel_global_position) / length(world_size);

	if (dither(uv * world_size.xz, dist) || skil_level > levelr){
		discard;
	}

	vec2 ruv = floor((uv * ws.xy) - ls) / ws.xy;

	vec4 world = texture(world_mask, vec3(ruv.x, ruv.y, level));

	if (erase_level > world.r){
		discard;
	}

	// Tileset texture
	float tid = world.g * TS;
	vec2 tileset_uv = vec2(UV.x, 1.0-UV.y) * ws.xy;
	vec4 ttex = texture(tileset, vec3(tileset_uv, tid) );
	vec4 ntex = texture(tileset_normalmap, vec3(tileset_uv, tid) );

	ALBEDO = ttex.rgb;
	NORMAL_MAP = ntex.rgb;
	NORMAL_MAP_DEPTH = normal;

	//vec4 t = texture(tex, UV * ws.xy);
	//ALBEDO = t.rgb * world.x;
	//ALBEDO.rgb = vec3(uv, 0.0);
	if (show_uv){
		ALBEDO.rg = vec2(0.0);
		ALBEDO.b = uv2.x;
	}
}
