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
    float noise_slider;
}
parameters;


layout(set = 0, binding = 3, std430) buffer output_parameters {
    int data[];
}
output_buffer;


// Invocation in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* Noise generation */
vec3 hash(vec4 p) {
    p = mod(p, 1e4); 
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


ivec3 voxel_to_global(ivec3 chunk_id, ivec3 local_voxel_position, ivec3 cube_size) {
    ivec3 chunk_global_position = (chunk_id * cube_size) - cube_size/2;
    
    ivec3 global_voxel_position = chunk_global_position + local_voxel_position;
    
    return global_voxel_position;
}


void main() {
    
    ivec3 ggid = ivec3(gl_GlobalInvocationID);

    int y = ggid.y;
    int z = int(float(ggid.x) / parameters.cube_size);
    int x = ggid.x - (z * int(parameters.cube_size));
   

    ivec3 coords = ivec3(x, y, z);
    vec3 coordsf = vec3(x, y, z);

    vec2 cube_size = vec2(parameters.cube_size, parameters.cube_size);

    vec3 offset = vec3(parameters.offset_x, parameters.offset_y, parameters.offset_z);

    ivec3 chunk_id = ivec3(offset); 
    
    ivec3 voxel = voxel_to_global(chunk_id, coords, ivec3(parameters.cube_size));
    float noise = seamless_noise(vec4((voxel / 1024.0) * parameters.scale, parameters.seed));

    float voxel_dist = length(float(offset));

    

    if (parameters.noise_slider > noise){
        noise = 0;
    }else{
        noise *= 8191.0;
        atomicAdd(output_buffer.data[0], 1);
    }
    
    vec4 packed = vec4(noise, noise, noise, 1.0);
    
    imageStore(output_texture, ggid.xy, vec4(packed));
}