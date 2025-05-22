shader_type canvas_item;

uniform sampler2D input_texture;
uniform vec2 input_texture_size = vec2(128.0);
uniform int mode : hint_range(0, 4, 1) = 0;

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


void fragment() {
	COLOR = vec4(1.0, 0.0, 0.0, 1.0);
}
