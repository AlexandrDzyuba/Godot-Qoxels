shader_type spatial;

render_mode unshaded, cull_front;

uniform sampler3D texture3d : filter_nearest; // 3D текстура
uniform vec3 cube_size = vec3(1.0); // Розмір куба
uniform int max_steps = 128; // Максимальна кількість кроків raymarching
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Базовий колір
uniform float min_distance = 10.0; // Мінімальна відстань для деталізації
uniform float max_distance = 100.0; // Максимальна відстань для деталізації
uniform int texture_resolution = 64; // Роздільна здатність текстури (64x64x64)

void raymarch(in vec3 ray_origin, in vec3 ray_dir, out vec4 color, in float detail) {
    color = vec4(0.0);
    vec3 inv_dir = 1.0 / ray_dir;

    vec3 t_min = (vec3(-0.5) * cube_size - ray_origin) * inv_dir;
    vec3 t_max = (vec3(0.5) * cube_size - ray_origin) * inv_dir;

    float t0 = max(max(min(t_min.x, t_max.x), min(t_min.y, t_max.y)), min(t_min.z, t_max.z));
    float t1 = min(min(max(t_min.x, t_max.x), max(t_min.y, t_max.y)), max(t_min.z, t_max.z));
    float step_size = (1.0 / float(max_steps)) * detail;

    if (t1 < 0.0 || t0 > t1) return;

    t0 = max(t0, 0.0);
    vec3 pos = ray_origin + (t0 + step_size * 0.5) * ray_dir;

    for (int i = 0; i < max_steps; i++) {
        if (t0 > t1) break;

        if (pos.x < -0.5 || pos.x > 0.5 || pos.y < -0.5 || pos.y > 0.5 || pos.z < -0.5 || pos.z > 0.5) {
            break; // Вихід за межі куба
        }

        vec3 tex_coords = (pos / cube_size) + 0.5;
        tex_coords = round(tex_coords * float(texture_resolution)) / float(texture_resolution); // Дискретизація

        vec4 density = texture(texture3d, tex_coords);
        if (density.x > 0.01) {
            color = density;
            return;
        }

        pos += ray_dir * step_size;
        t0 += step_size;
    }
}


void fragment() {
    // Позиція камери в локальному просторі об'єкта
    vec3 ray_origin = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // Позиція фрагмента в локальному просторі об'єкта
    vec3 fragment_pos = ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);

    // Напрямок променя
    vec3 ray_dir = normalize(fragment_pos - ray_origin);

    vec4 color = vec4(fragment_pos.x, fragment_pos.y, fragment_pos.z, 1.0);

	ray_origin = (ray_origin - NODE_POSITION_WORLD);

    raymarch(ray_origin , ray_dir, color, 1.0);

    ALBEDO = color.rgb;
    if (color.a <= 0.0)
        discard; // Пропустити пікселі без даних
}


void raymarch_discrete(in vec3 ray_origin, in vec3 ray_dir, out vec4 color) {
    color = vec4(0.0);

    // Розмір одного вокселя
    vec3 voxel_size = cube_size / float(texture_resolution);
	vec3 inv_dir = 1.0 / ray_dir;
	vec3 t_min = (vec3(-0.5) * cube_size - ray_origin) * inv_dir;
    vec3 t_max = (vec3(0.5) * cube_size - ray_origin) * inv_dir;

    float t0 = max(0.0, max(max(min(t_min.x, t_max.x), min(t_min.y, t_max.y)), min(t_min.z, t_max.z)));
    float t1 = min(min(max(t_min.x, t_max.x), max(t_min.y, t_max.y)), max(t_min.z, t_max.z));

    if (t1 < 0.0 || t0 > t1) return;


    // Нормалізація початкової точки у координати текстури
    vec3 norm_ray_origin = (ray_origin + cube_size * 0.5) / cube_size;
    vec3 norm_ray_dir = ray_dir / cube_size;

    // Початкова воксельна координата
    ivec3 voxel_coords = ivec3(floor(norm_ray_origin * float(texture_resolution)));

    // Крок променя
    ivec3 vstep = ivec3(sign(norm_ray_dir));
    vec3 delta_t = abs(voxel_size / ray_dir);

    // Початкові межі для кожної осі
    vec3 next_voxel_boundary = (vec3(voxel_coords) + vec3(vstep)) * voxel_size - norm_ray_origin;
    vec3 t_next = abs(next_voxel_boundary / norm_ray_dir);

    for (int i = 0; i < max_steps; i++) {
		if (any(lessThan(voxel_coords, ivec3(0))) || any(greaterThanEqual(voxel_coords, ivec3(texture_resolution)))) {
		    return; // Вихід, якщо виходимо за межі текстури
		}

		 // Отримання текстурних координат
        vec3 tex_coords = vec3(voxel_coords) / float(texture_resolution);

        float density = texture(texture3d, tex_coords).r;
        if (density > 0.01) {
            color = base_color * density;
            return;
        }

        // Рух до наступного вокселя
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

