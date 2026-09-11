shader_type sky;

// A product-photo studio. The camera sees a plain backdrop, while reflections
// and ambient light see a soft room with two light boxes -- that is what makes
// the Metallic and Clearcoat presets readable in front of a plain background.

uniform vec3 backdrop : source_color = vec3(0.14, 0.145, 0.16);
uniform vec3 ceiling : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 walls : source_color = vec3(0.55, 0.56, 0.58);
uniform vec3 floor_color : source_color = vec3(0.3, 0.3, 0.31);
uniform float softbox_energy = 3.5;

// 1 inside a soft-edged disc of `radius` (radians) around `center`, else 0.
float softbox(vec3 dir, vec3 center, float radius) {
	float angle = acos(clamp(dot(dir, normalize(center)), -1.0, 1.0));
	return 1.0 - smoothstep(radius * 0.6, radius, angle);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		vec3 room = mix(walls, ceiling, smoothstep(0.1, 0.9, EYEDIR.y));
		room = mix(room, floor_color, smoothstep(0.0, -0.4, EYEDIR.y));
		room += softbox_energy * softbox(EYEDIR, vec3(-0.5, 0.8, 0.6), 0.5);
		room += 0.6 * softbox_energy * softbox(EYEDIR, vec3(0.9, 0.25, -0.4), 0.4);
		COLOR = room;
	} else {
		COLOR = backdrop;
	}
}
