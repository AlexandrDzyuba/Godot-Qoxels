shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture;

uniform sampler2D ramp;

uniform float zNear = 2;
uniform float zFar = 10.0;

uniform float width = 1.0;

vec3 overlay(vec3 base, vec3 blend) {
    return mix(2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend), clamp(base, 0.0, 1.0));
}

float textureCavity(sampler2D normal_texture, vec2 uv, vec2 screen_pixel_size){
	vec4 normal = texture(normal_texture, uv);
	vec4 normal_m = texture(normal_texture, uv - vec2(screen_pixel_size.x*width, 0));
	vec4 normal_p = texture(normal_texture, uv + vec2(0, screen_pixel_size.y*width));

	normal.r = texture(ramp, vec2(normal.r)).r;
	normal.g = texture(ramp, vec2(normal.g)).r;

	float r_off = texture(ramp, vec2(normal_m.r)).r;
	float g_off = texture(ramp, vec2(normal_p.g)).r;

	return (normal.r - r_off) + (normal.g - g_off) + 0.5;
}

float scaledDepth(sampler2D depth_texture, vec2 uv, mat4 inv_proj_mat){
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	vec4 view = inv_proj_mat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = view.z;
	return (zFar * zNear) / (zFar + (linear_depth * (zNear - zFar)));
}

void vertex(){
	 //POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 origin = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec2 SCREEN_PIXEL_SIZE = 1.0 / VIEWPORT_SIZE;

	vec2 uv = SCREEN_UV;

	vec4 normal = texture(NORMAL_TEXTURE, uv);
	vec4 normal_m = texture(NORMAL_TEXTURE, uv - vec2(SCREEN_PIXEL_SIZE.x*width, 0));
	vec4 normal_p = texture(NORMAL_TEXTURE, uv + vec2(0, SCREEN_PIXEL_SIZE.y*width));

	normal.r = texture(ramp, vec2(normal.r)).r;
	normal.g = texture(ramp, vec2(normal.g)).r;

	float r_off = texture(ramp, vec2(normal_m.r)).r;
	float g_off = texture(ramp, vec2(normal_p.g)).r;

	float nres = (normal.r - r_off) + (normal.g - g_off) + 0.5;

	ALBEDO = overlay(origin.rgb, vec3(clamp(nres, 0.0, 1.0)));

}