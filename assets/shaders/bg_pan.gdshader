shader_type canvas_item;
uniform float blur_amount = 3.5;
uniform float zoom = 1.14;
uniform float pan_speed = 0.03;

void fragment() {
	vec2 uv = (UV - 0.5) / zoom + 0.5;
	uv.x += sin(TIME * pan_speed) * 0.045;
	uv.y += sin(TIME * pan_speed * 0.65 + 1.8) * 0.03;
	vec2 px = blur_amount / vec2(textureSize(TEXTURE, 0));
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) * 0.4);
			col += texture(TEXTURE, uv + vec2(float(x), float(y)) * px) * w;
			total += w;
		}
	}
	COLOR = col / total;
}
