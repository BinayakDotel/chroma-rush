class_name Look
## The materials behind the game's look, in one place: the soft surface used by everything solid,
## glass, glowing parts, light beams and the soft patches drawn on the road. Worlds adjust the
## soft surface through their `look` entry (see Themes).

const SoftShader := preload("res://shaders/soft.gdshader")
const GlassShader := preload("res://shaders/glass.gdshader")
const BlobShader := preload("res://shaders/blob.gdshader")

static var _dot: GradientTexture2D

## Soft-surface settings a world does not override.
const DEFAULTS := {"ramp": 0.6, "under": 0.55, "rim_color": Color.WHITE, "rim": 0.22, "gloss": 0.0, "glow": 0.0}


## The soft, vertex-coloured surface (shaders/soft.gdshader). `world` is a theme's `look`
## dictionary; `overrides` changes individual settings for one material (e.g. gloss for paint).
static func soft(world := {}, overrides := {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SoftShader
	var values := DEFAULTS.duplicate()
	values.merge(world, true)
	values.merge(overrides, true)
	for key: String in values:
		material.set_shader_parameter(key, values[key])
	return material


static func glass() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GlassShader
	return material


## Unshaded and brighter than white, so it blooms: lights, flames, lava seams.
static func glowing(boost := 1.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(boost, boost, boost)
	return material


## Additive light for beams: vertex colours carry the fade (their alpha).
static func beam(color: Color, strength := 0.4) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(color.r, color.g, color.b, strength)
	return material


## A soft round patch on the road (shaders/blob.gdshader): a contact shadow, or with `ring` a
## glowing ring, tinted with `shade`.
static func blob(ring := false, shade := Color(0.0, 0.0, 0.0, 0.38)) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BlobShader
	material.set_shader_parameter("ring", 1.0 if ring else 0.0)
	material.set_shader_parameter("shade", shade)
	material.render_priority = -1
	return material


## A soft round dot (opaque in the middle, fading out to the edge) for particles.
static func soft_dot() -> GradientTexture2D:
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.75))
		_dot = GradientTexture2D.new()
		_dot.gradient = gradient
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 64
		_dot.height = 64
	return _dot


## A flat square of `size` metres lying on the road at height `y`, for blob materials.
static func patch(size: float, y: float, material: Material, into: ArrayMesh = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var corners := [Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h), Vector3(-h, y, h)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
	var mesh := st.commit(into) if into else st.commit()
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## A cone of light standing on the road, bright at the base and fading out towards the top.
static func beam_mesh(radius: float, height: float, material: Material) -> ArrayMesh:
	var kit := MeshKit.new(0, true)
	var fade := func(p: Vector3, _n: Vector3) -> Color:
		var t := clampf(p.y / height, 0.0, 1.0)
		return Color(1.0, 1.0, 1.0, (1.0 - t) * (1.0 - t))
	kit.lathe(Vector3.ZERO, Vector3.UP, [Vector2(radius, 0.0), Vector2(radius * 0.8, height * 0.35),
		Vector2(radius * 0.62, height * 0.7), Vector2(radius * 0.5, height)], 12, fade)
	return kit.commit(material)
