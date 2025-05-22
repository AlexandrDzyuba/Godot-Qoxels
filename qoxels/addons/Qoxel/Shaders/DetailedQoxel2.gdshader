shader_type spatial;

render_mode unshaded, cull_front;

uniform sampler3D texture3d : filter_nearest; // 3D текстура
uniform vec3 cube_size = vec3(1.0); // Розмір куба
uniform int max_steps = 128; // Максимальна кількість кроків raymarching
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Базовий колір
uniform int texture_resolution = 64; // Роздільна здатність текстури (64x64x64)

void raymarch_discrete(in vec3 ray_origin, in vec3 ray_dir, out vec4 color) {
    color = vec4(0.0);

    // Розмір одного вокселя в просторі куба
    vec3 voxel_size = cube_size / float(texture_resolution);
    vec3 inv_dir = 1.0 / ray_dir;

    // Знаходимо точки входу і виходу променя з куба
    vec3 t_min = (vec3(0.0) - ray_origin) * inv_dir;
    vec3 t_max = (cube_size - ray_origin) * inv_dir;

    vec3 t1 = min(t_min, t_max);
    vec3 t2 = max(t_min, t_max);

    float t0 = max(max(t1.x, t1.y), max(t1.z, 0.0));
    float t1_final = min(t2.x, min(t2.y, t2.z));

    if (t1_final < t0) return; // Якщо промінь не перетинає куб

    // Початкова позиція променя у вокселях
    vec3 voxel_coords = floor((ray_origin + ray_dir * t0) / voxel_size);
    vec3 vstep = sign(ray_dir); // Напрямок руху по осях

    // Відстань між межами сусідніх вокселів
    vec3 delta_t = abs(voxel_size / ray_dir);
    vec3 t_next = (voxel_coords + step(vec3(0.0), vstep)) * voxel_size - ray_origin;
    t_next /= ray_dir;

    for (int i = 0; i < max_steps; i++) {
        // Вирахувати координати текстури (нормалізовані)
        vec3 tex_coords = voxel_coords / cube_size;

        // Перевірка меж текстури
        if (any(lessThan(tex_coords, vec3(0.0))) || any(greaterThanEqual(tex_coords, vec3(1.0))))
            return;

        // Отримати щільність з текстури
        float density = texture(texture3d, tex_coords).r;

        if (density > 0.01) {
            color = base_color * density;
            return; // Промінь зупиняється на першому непрозорому вокселі
        }

        // Перехід до наступного вокселя
        if (t_next.x < t_next.y && t_next.x < t_next.z) {
            voxel_coords.x += vstep.x;
            t_next.x += delta_t.x;
        } else if (t_next.y < t_next.z) {
            voxel_coords.y += vstep.y;
            t_next.y += delta_t.y;
        } else {
            voxel_coords.z += vstep.z;
            t_next.z += delta_t.z;
        }
    }
}

void fragment() {
    // Початкова точка променя в просторі світу
    vec3 ray_origin = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // Фрагментна позиція в просторі світу
    vec3 fragment_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Вектор напрямку променя
    vec3 ray_dir = normalize(fragment_pos - ray_origin);

    // Перетворити початок променя в локальний простір куба
    ray_origin = (ray_origin - NODE_POSITION_WORLD) + cube_size / 2.0;

    vec4 color = vec4(0.0);
    raymarch_discrete(ray_origin, ray_dir, color);

    ALBEDO = color.rgb;
    if (color.a <= 0.0)
        discard; // Пропустити прозорі пікселі
}
