float set_compressed(float a, float b, float meta1, float meta2) {
    // Обмежуємо значення a, b, meta1, meta2 в межах від 0 до відповідних максимумів
    a = clamp(a, 0.0, 8191.0);
    b = clamp(b, 0.0, 8191.0);
    meta1 = clamp(meta1, 0.0, 7.0);
    meta2 = clamp(meta2, 0.0, 7.0);

    // Стискаємо значення, використовуючи 13 біт для a, 13 біт для b, і по 3 біти для кожного метаданого
    return floor(a) * 8192.0 + floor(b) + floor(meta1) * 8192.0 * 8192.0 + floor(meta2) * 8192.0 * 8192.0 * 8.0;
}

vec4 get_compressed(float compressed) {
    // Виділяємо метадані meta2
    float meta2 = floor(compressed / (8192.0 * 8192.0 * 8.0));
    compressed -= meta2 * 8192.0 * 8192.0 * 8.0;

    // Виділяємо метадані meta1
    float meta1 = floor(compressed / (8192.0 * 8192.0));
    compressed -= meta1 * 8192.0 * 8192.0;

    // Виділяємо значення b
    float b = mod(compressed, 8192.0);

    // Виділяємо значення a
    float a = floor(compressed / 8192.0);

    return vec4(a, b, meta1, meta2);
}

vec2 get_atlas_uv(vec2 uv, int index, int count) {
    float size = 1.0 / float(count);
    return vec2(uv.x * size + float(index) * size, uv.y);
}

// Return layer data for [layer] and [layer+1]
vec4 decompress(sampler2D compressed_tex, vec2 uv, float cube_size, int layer){
    float size = 1.0 / (cube_size / 8.0);
    int l_div_8 = layer / 8;
    int l_mod_8 = layer % 8;

    // Обчислення зміщеного UV
    vec2 compressed_uv = vec2(uv.x * size + float(l_div_8) * size, uv.y);
    vec4 compressed = texture(compressed_tex, compressed_uv);

    // Отримання значення каналу і модифікованого layer
    int channel = int(l_mod_8) / 2;

    vec4 decompressed = get_compressed(compressed[channel]);

    // Витягування необхідних значень
    float idx = decompressed[int(l_mod_8) % 2];
    float meta = decompressed[(int(l_mod_8) % 2) + 2];

    float second_idx = decompressed[(int(l_mod_8 + 1) % 2)];
    float second_meta = decompressed[(int(l_mod_8 + 1) % 2) + 2];

    return vec4(idx, meta, second_idx, second_meta);
}



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