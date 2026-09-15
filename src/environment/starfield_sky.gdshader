shader_type sky;

// A product-photo studio adrift in space. The camera sees a starfield, while
// reflections and ambient light still see a soft room with two light boxes --
// that is what keeps the Metallic and Clearcoat presets readable in front of
// an almost black background.
//
// Deliberately no TIME: a sky shader that reads it gets its reflections
// re-rendered every frame, although only the part the camera sees would
// change. The stars move whenever the camera does, and it circles on its own
// when left alone.

// The studio: reflections and ambient light only.
uniform vec3 ceiling : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 walls : source_color = vec3(0.55, 0.56, 0.58);
uniform vec3 floor_color : source_color = vec3(0.3, 0.3, 0.31);
uniform float softbox_energy = 3.5;

// The starfield: what the camera sees.
uniform vec3 space_color : source_color = vec3(0.01, 0.012, 0.02);
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 4.0) = 1.0;
// Radius of a faint star in pixels, so stars stay equally crisp at any
// resolution. Brighter ones are drawn a little larger.
uniform float star_size : hint_range(0.3, 3.0) = 0.8;
uniform vec3 milky_way_color : source_color = vec3(0.6, 0.65, 0.8);
uniform float milky_way_strength : hint_range(0.0, 0.5) = 0.05;
// The Milky Way runs around the sky square to this direction. The default
// sends it diagonally behind the cube as the camera first sees it.
uniform vec3 galactic_pole = vec3(-0.69, 0.72, 0.07);
uniform vec3 nebula_color_a : source_color = vec3(0.45, 0.15, 0.6);
uniform vec3 nebula_color_b : source_color = vec3(0.1, 0.35, 0.6);
uniform float nebula_strength : hint_range(0.0, 0.5) = 0.12;

// 1 inside a soft-edged disc of `radius` (radians) around `center`, else 0.
float softbox(vec3 dir, vec3 center, float radius) {
	float angle = acos(clamp(dot(dir, normalize(center)), -1.0, 1.0));
	return 1.0 - smoothstep(radius * 0.6, radius, angle);
}

// Three / one random values in 0..1 per grid cell ("Hash without Sine", Dave
// Hoskins): stable for whole-number inputs, no sin() precision issues.
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
				mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
				mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
			f.z);
}

// Cloudy noise around 0.5, for gas and dust.
float fbm(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.03 + 17.1;
		amplitude *= 0.5;
	}
	return sum;
}

// Blue-white to warm yellow, most of them close to white -- like real stars.
vec3 star_tint(float t) {
	vec3 tint = mix(vec3(0.65, 0.75, 1.0), vec3(1.0), smoothstep(0.0, 0.45, t));
	return mix(tint, vec3(1.0, 0.78, 0.55), smoothstep(0.65, 1.0, t));
}

// One layer of stars, about `scale` cells per radian. Space around the sphere of
// directions is cut into cubes; a cube may hold one star at a random spot, if
// that spot lies close enough to the sphere to be pushed onto it. Stars thus sit
// anywhere, never on a grid, and a star is never cut off at a cube's wall:
// looking at the 2x2x2 cubes nearest to `dir` finds every star that can reach
// it, as long as a star stays within a tenth of a cube -- hence the cap on
// `radius`.
vec3 star_layer(vec3 dir, float scale, float density, float radius, float brightness) {
	vec3 p = dir * scale;
	float r = min(radius * scale, 0.1);  // in cube widths
	vec3 corner = floor(p - 0.5);
	vec3 light = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec3 cell = corner + vec3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1));
		vec3 h = hash33(cell);
		vec3 spot = cell + 0.3 + 0.4 * hash33(cell + 19.19);
		float spot_distance = length(spot);
		if (h.x > density || abs(spot_distance - scale) > 0.5) {
			continue;
		}
		float d = length(p - spot * (scale / spot_distance));
		light += star_tint(h.y) * (0.1 + 0.9 * h.z * h.z * h.z) * exp(-d * d / (r * r));
	}
	return light * brightness;
}

// The band of the Milky Way, brighter where its gas is dense, with dark dust
// lanes. `band` tells the caller how deep in the band `dir` lies (0..1).
vec3 milky_way(vec3 dir, out float band) {
	float height = dot(dir, normalize(galactic_pole));
	band = exp(-height * height * 14.0);
	float gas = fbm(dir * 3.0);
	float dust = smoothstep(0.5, 0.7, fbm(dir * 7.0 + 5.3));
	return milky_way_color * milky_way_strength * band * (0.2 + 2.0 * gas * gas) * (1.0 - 0.75 * dust);
}

// A few faint, colored clouds of gas scattered over the sky.
vec3 nebulae(vec3 dir) {
	float gas = smoothstep(0.45, 0.8, fbm(dir * 1.7 + 11.0));
	vec3 tint = mix(nebula_color_a, nebula_color_b, smoothstep(0.35, 0.65, fbm(dir * 1.1 - 7.0)));
	return tint * nebula_strength * gas * gas;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		vec3 room = mix(walls, ceiling, smoothstep(0.1, 0.9, EYEDIR.y));
		room = mix(room, floor_color, smoothstep(0.0, -0.4, EYEDIR.y));
		room += softbox_energy * softbox(EYEDIR, vec3(-0.5, 0.8, 0.6), 0.5);
		room += 0.6 * softbox_energy * softbox(EYEDIR, vec3(0.9, 0.25, -0.4), 0.4);
		COLOR = room;
	} else {
		// The angle one pixel spans.
		float pixel = max(length(dFdx(EYEDIR)), length(dFdy(EYEDIR)));
		float radius = pixel * star_size;
		float band;
		vec3 backdrop = space_color + nebulae(EYEDIR) + milky_way(EYEDIR, band);
		// Dense faint ones (crowding into the Milky Way), fewer brighter ones,
		// and a handful bright enough to glow.
		vec3 stars = star_layer(EYEDIR, 110.0, star_density * (0.35 + 1.3 * band), radius, 0.4);
		stars += star_layer(EYEDIR, 45.0, star_density * 0.5, radius * 1.25, 1.2);
		stars += star_layer(EYEDIR, 16.0, star_density * 0.4, radius * 1.6, 6.0);
		COLOR = backdrop + stars * star_brightness;
	}
}
