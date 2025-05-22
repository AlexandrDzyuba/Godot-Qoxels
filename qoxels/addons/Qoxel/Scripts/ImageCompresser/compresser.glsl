#[compute]
#version 450

// A binding to the buffer 
layout(set = 0, binding = 0, rgba32f) readonly uniform image2D input_texture;
layout(set = 0, binding = 1, rgba32f) writeonly restrict uniform image2D output_texture;

layout(set = 0, binding = 2, std430) readonly buffer custom_parameters {
    float seed;
    float scale;
    
    float offset_x;
    float offset_y;
    float offset_z;

    float cube_size;
}
parameters;

// Invocation in the (x, y, z) dimension
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

float set_compressed(float a, float b, float meta1, float meta2) {
    a = clamp(a, 0.0, 8191.0);
    b = clamp(b, 0.0, 8191.0);
    meta1 = clamp(meta1, 0.0, 7.0);
    meta2 = clamp(meta2, 0.0, 7.0);

    return floor(a) * 8192.0 + floor(b) + floor(meta1) * 8192.0 * 8192.0 + floor(meta2) * 8192.0 * 8192.0 * 8.0;
}

vec2 uv3_to_atlas_uv(vec2 uv, float layer, float layers_count) {
    float atlas_size = sqrt(layers_count);

    float row = floor(layer / atlas_size);
    float col = mod(layer, atlas_size);

    vec2 atlas_uv = uv / atlas_size + vec2(col, row) / atlas_size;
    
    return atlas_uv;
}

vec3 atlas_uv_to_uv3(vec2 atlas_uv, float max_z_layers) {
    float atlas_size = sqrt(max_z_layers);

    vec2 row_col = floor(atlas_uv * atlas_size);

    float layer = row_col.y * atlas_size + row_col.x;

    vec2 uv = fract(atlas_uv * atlas_size);

    return vec3(uv, layer);
}


vec2 get_local_uv(vec2 uv, float count) {
    return vec2(fract(uv.x * count), uv.y);
}

/* Noise generation */

vec3 hash(vec4 p) {
    p = vec4(dot(p, vec4(127.1, 311.7, 74.7, 1.0)),
             dot(p, vec4(269.5, 183.3, 246.1, 1.0)),
             dot(p, vec4(113.5, 271.9, 124.6, 1.0)),
             dot(p, vec4(1.0, 1.0, 1.0, 1.0)));
    return fract(sin(p.xyz) * 43758.5453);
}

float noise(vec4 p) {
    vec3 i = floor(p.xyz);
    vec3 f = fract(p.xyz);

    f = f * f * (3.0 - 2.0 * f);

    return mix(mix(mix(dot(hash(vec4(i + vec3(0.0, 0.0, 0.0), p.w)), f - vec3(0.0, 0.0, 0.0)), 
                        dot(hash(vec4(i + vec3(1.0, 0.0, 0.0), p.w)), f - vec3(1.0, 0.0, 0.0)), f.x),
                   mix(dot(hash(vec4(i + vec3(0.0, 1.0, 0.0), p.w)), f - vec3(0.0, 1.0, 0.0)), 
                        dot(hash(vec4(i + vec3(1.0, 1.0, 0.0), p.w)), f - vec3(1.0, 1.0, 0.0)), f.x), f.y),
               mix(mix(dot(hash(vec4(i + vec3(0.0, 0.0, 1.0), p.w)), f - vec3(0.0, 0.0, 1.0)), 
                        dot(hash(vec4(i + vec3(1.0, 0.0, 1.0), p.w)), f - vec3(1.0, 0.0, 1.0)), f.x),
                   mix(dot(hash(vec4(i + vec3(0.0, 1.0, 1.0), p.w)), f - vec3(0.0, 1.0, 1.0)), 
                        dot(hash(vec4(i + vec3(1.0, 1.0, 1.0), p.w)), f - vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float seamless_noise(vec4 p) {
    
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        n += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return clamp(n * 3.0, 0.0, 1.0);
}
// Noise generation end.


void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    vec4 tex = imageLoad(input_texture, coords);
    vec2 tsize = imageSize(input_texture);
    vec2 cube_size = vec2(parameters.cube_size, parameters.cube_size);

    
    vec3 offset = vec3(parameters.offset_x, parameters.offset_y, parameters.offset_z); 
    
    vec2 uv = ((vec2( fract(float(coords.x) / parameters.cube_size) , coords.y / parameters.cube_size) + offset.xy)) * parameters.scale;
    
    vec2 zseed = vec2(offset.z / parameters.cube_size, parameters.seed);

    vec4 packed = vec4(0.0, 0.0, 0.0, 0.0);

    for (int i = 0; i < 4; i++){
        float z = (int(float(coords.x) / parameters.cube_size) * 8.0) + (i * 2.0);
        
        float a = seamless_noise(vec4(uv, vec2((offset.z + z + i) / parameters.cube_size, parameters.seed)));
        float b = seamless_noise(vec4(uv, vec2((offset.z + z + (i + 1)) / parameters.cube_size, parameters.seed)));
        
        packed[i] = set_compressed( floor(a * 8191.0), floor(b * 8191.0), 0.0, 0.0);
    }

    
    imageStore(output_texture, coords, vec4(packed));
}