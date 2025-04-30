shader_type sky;

// Uniforms controlled by GDScript
uniform vec3 sun_direction;
uniform vec3 moon_direction;
uniform float sun_progress;  // 0=rise, 0.5=peak, 1=set
uniform float moon_progress; // 0=rise, 0.5=peak, 1=set

// Configurable Colors (Editable in ShaderMaterial)
uniform vec3 day_color : source_color = vec3(0.4, 0.7, 1.0);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.6, 0.3);
uniform vec3 night_color : source_color = vec3(0.05, 0.05, 0.15);

// Sun/Moon Appearance
uniform vec4 sun_tint : source_color = vec4(1.0, 0.9, 0.7, 5.0); // Use alpha as intensity multiplier
uniform float sun_size : hint_range(0.95, 0.999, 0.001) = 0.995; // Based on dot product, closer to 1 = smaller size
uniform float sun_blur : hint_range(0.001, 0.05, 0.001) = 0.004;

uniform vec4 moon_tint : source_color = vec4(0.8, 0.8, 0.9, 2.0); // Use alpha as intensity multiplier
uniform float moon_size : hint_range(0.95, 0.999, 0.001) = 0.996;
uniform float moon_blur : hint_range(0.001, 0.05, 0.001) = 0.005;

// Textures (Optional)
uniform sampler2D sun_texture : source_color;
uniform sampler2D moon_texture : source_color;
uniform bool use_textures = false; // Enable this via GDScript if textures are set

// Helper to draw sun/moon (disk or texture)
vec4 draw_celestial(vec3 eye_dir, vec3 body_dir, float body_progress, vec4 tint, float size_dot, float blur, sampler2D tex, bool use_tex) {
	// Don't draw if it's not the active part of its cycle
	if (body_progress <= 0.0 || body_progress >= 1.0) {
		return vec4(0.0);
	}

	// Calculate how aligned the view direction is with the body direction
	float dot_prod = dot(normalize(eye_dir), normalize(body_dir));

	// Create a smooth disk based on alignment
	float disk = smoothstep(size_dot - blur, size_dot + blur, dot_prod);

	vec4 color = vec4(0.0);
	if (disk > 0.0) {
		float fade_intensity = sin(body_progress * PI); // Fade in/out (0 -> 1 -> 0)

		if (use_tex) {
			// Very basic texture mapping - treats the visible disk as a quad
			// Calculate vectors pointing right and up relative to the body's direction
			vec3 right_vec = normalize(cross(vec3(0.0, 1.0, 0.0), body_dir));
			vec3 up_vec = normalize(cross(body_dir, right_vec));
			// Project eye_dir onto these vectors to get UV-like coordinates
			// Scale coordinates based on the 'disk' size
			float max_extent = sqrt(1.0 - size_dot * size_dot); // Approx angular radius
			float u = (dot(normalize(eye_dir), right_vec) / max_extent) * 0.5 + 0.5;
			float v = (dot(normalize(eye_dir), up_vec) / max_extent) * 0.5 + 0.5;

			// Only sample if UV seems valid (prevents edge artifacts)
			if (u > 0.0 && u < 1.0 && v > 0.0 && v < 1.0) {
				color = texture(tex, vec2(u, v)) * tint * tint.a * fade_intensity * disk;
			} else {
				color = vec4(0.0); // Outside valid UV
			}
		} else {
			// Simple colored disk
			color = vec4(tint.rgb * tint.a * fade_intensity * disk, 1.0);
		}
	}
	return color;
}

void sky() {
	// --- Sky Color Calculation ---
	// Use direct sun elevation: approx -1 (nadir) to 1 (peak), 0 is horizon
	float sun_alt = sun_direction.y;

	// Determine base day intensity (0=night, 1=day)
	// Start transition slightly below horizon, finish slightly above
	float day_intensity = smoothstep(-0.1, 0.2, sun_alt);

	// Determine sunset intensity (strongest AT the horizon, fades out quickly above/below)
	float horizon_zone_width = 0.2; // Adjust: How far from horizon sunset color applies
	// Calculate intensity based on distance from horizon (abs(sun_alt)). Peak = 1.0 at horizon.
	// Intensity decreases as abs(sun_alt) increases.
	float sunset_intensity = 1.0 - smoothstep(0.0, horizon_zone_width, abs(sun_alt));

	// Start with night color
	vec3 sky_color_lerp = night_color;
	// Mix towards day color based on overall day intensity
	sky_color_lerp = mix(sky_color_lerp, day_color, day_intensity);

	// Mix towards sunset color based on sunset intensity.
	// The clamp ensures the mix factor doesn't exceed 1.0.
	// Multiply sunset_intensity (e.g., by 1.5 or 2.0) if the effect is too subtle.
	vec3 final_sky_color = mix(sky_color_lerp, sunset_color, clamp(sunset_intensity * 1.5, 0.0, 1.0));

	// Adjust gradient based on view direction (slightly darker/different color at horizon)
	// This makes the sky near the horizon slightly darker/tinted by the bottom color mix
	final_sky_color = mix(final_sky_color * 0.8, final_sky_color, smoothstep(0.0, 0.3, EYEDIR.y));


	// --- Sun & Moon Drawing ---
	// (This part remains the same)
	vec4 sun_draw = draw_celestial(EYEDIR, sun_direction, sun_progress, sun_tint, sun_size, sun_blur, sun_texture, use_textures);
	vec4 moon_draw = draw_celestial(EYEDIR, moon_direction, moon_progress, moon_tint, moon_size, moon_blur, moon_texture, use_textures);

	// --- Combine ---
	// Add sun and moon colors onto the sky color
	COLOR = final_sky_color + sun_draw.rgb + moon_draw.rgb;
	//COLOR = vec3(sun_progress);
}