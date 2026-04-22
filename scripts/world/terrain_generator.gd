class_name TerrainGenerator
extends RefCounted

# --- Tuning constants ---
const PATCH_HALF  : float = 100.0   # patch is 200 × 200 world units
const GRID_STEPS  : int   = 128     # 129 × 129 vertex grid (16 641 verts)
const MAX_HEIGHT  : float = 22.0    # tallest mountain peak
const RIVER_DEPTH : float = 5.5     # how deep river valleys are carved
const RIVER_BAND  : float = 0.065   # noise-zero band width → river width
const CLIFF_SLOPE : float = 1.25    # gradient magnitude threshold for rock/cliff

# --- Noise layers ---
var _continental : FastNoiseLite   # large-scale highland / lowland mask
var _mountain    : FastNoiseLite   # ridged peaks
var _hills       : FastNoiseLite   # rolling lowland hills
var _detail      : FastNoiseLite   # surface micro-roughness
var _warp        : FastNoiseLite   # domain warp (organic deformation)
var _river       : FastNoiseLite   # river channel mask


func _init(p_seed: int = 0) -> void:
	_continental = _make(p_seed,     0.005, FastNoiseLite.FRACTAL_FBM,    3)
	_mountain    = _make(p_seed + 1, 0.018, FastNoiseLite.FRACTAL_RIDGED, 5)
	_hills       = _make(p_seed + 2, 0.025, FastNoiseLite.FRACTAL_FBM,    4)
	_detail      = _make(p_seed + 3, 0.10,  FastNoiseLite.FRACTAL_FBM,    2)
	_warp        = _make(p_seed + 4, 0.007, FastNoiseLite.FRACTAL_FBM,    2)
	_river       = _make(p_seed + 5, 0.011, FastNoiseLite.FRACTAL_FBM,    2)


# Returns terrain height at world-space (x, z).
func sample_height(x: float, z: float) -> float:
	# 1. Domain warp — twists coordinates so features look organic
	var wx : float = x + _warp.get_noise_2d(x,          z         ) * 35.0
	var wz : float = z + _warp.get_noise_2d(x + 419.2, z + 831.7) * 35.0

	# 2. Continental mask [0..1]: 0 = lowland, 1 = highland/mountain base
	var cont : float = _continental.get_noise_2d(wx, wz) * 0.5 + 0.5
	cont = _smoothstep(0.35, 0.65, cont)

	# 3. Ridged mountain layer — FRACTAL_RIDGED already produces peaks
	var peak : float = _mountain.get_noise_2d(wx, wz) * 0.5 + 0.5
	peak = pow(peak, 1.8)   # sharpen peaks, flatten broad bases

	# 4. Rolling hills [0..1]
	var hill : float = _hills.get_noise_2d(wx, wz) * 0.5 + 0.5

	# 5. Blend: lowlands get gentle hills, highlands get mountains
	var h : float = lerpf(hill * 4.0, peak * MAX_HEIGHT, cont)

	# 6. Micro surface roughness
	h += _detail.get_noise_2d(wx, wz) * 0.5

	# 7. River valley carving — narrow band around noise zero-crossings
	var rv         : float = _river.get_noise_2d(wx, wz)
	var carve      : float = maxf(0.0, RIVER_BAND - absf(rv)) / RIVER_BAND
	carve = pow(carve, 0.65)
	# Only carve in lowlands — rivers don't cut through mountaintops
	var alt_mask : float = clampf(1.0 - h / (MAX_HEIGHT * 0.55), 0.0, 1.0)
	h -= carve * RIVER_DEPTH * alt_mask

	return h


# Returns a vertex color based on altitude and surface slope.
func surface_color(height: float, slope: float) -> Color:
	# Snow caps
	if height > MAX_HEIGHT * 0.78:
		return Color(0.93, 0.94, 0.98)
	# Cliff / rock face (steep slope)
	if slope > CLIFF_SLOPE:
		return Color(0.44, 0.37, 0.28)
	# Riverbed / lowland dirt
	if height < 0.8:
		return Color(0.38, 0.28, 0.16)
	# Grass — lighter at higher altitude, darker near rivers
	var t : float = clampf(height / (MAX_HEIGHT * 0.5), 0.0, 1.0)
	return lerp(Color(0.18, 0.44, 0.14), Color(0.28, 0.52, 0.20), t)


# Builds and returns the terrain ArrayMesh.
func build_mesh() -> ArrayMesh:
	var row  : int   = GRID_STEPS + 1
	var step : float = (PATCH_HALF * 2.0) / float(GRID_STEPS)

	# --- Pre-compute height grid ---
	var heights := PackedFloat32Array()
	heights.resize(row * row)
	for iz: int in range(row):
		for ix: int in range(row):
			heights[iz * row + ix] = sample_height(
				-PATCH_HALF + ix * step,
				-PATCH_HALF + iz * step
			)

	# --- Build indexed mesh via SurfaceTool ---
	# Indexed vertices allow generate_normals() to produce smooth shading.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz: int in range(row):
		for ix: int in range(row):
			var i   : int   = iz * row + ix
			var pos : Vector3 = Vector3(
				-PATCH_HALF + ix * step,
				heights[i],
				-PATCH_HALF + iz * step
			)
			var sl : float = _slope(ix, iz, heights, step, row)
			st.set_color(surface_color(heights[i], sl))
			st.add_vertex(pos)

	for iz: int in range(GRID_STEPS):
		for ix: int in range(GRID_STEPS):
			var a : int = iz * row + ix
			var b : int = (iz + 1) * row + ix
			var c : int = (iz + 1) * row + (ix + 1)
			var d : int = iz * row + (ix + 1)
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(a); st.add_index(c); st.add_index(d)

	st.generate_normals()
	return st.commit()


# --- Helpers ---

# Gradient magnitude at grid cell (ix, iz), in height-units per world-unit.
func _slope(ix: int, iz: int, heights: PackedFloat32Array,
			step: float, row: int) -> float:
	var x0 : int = clampi(ix - 1, 0, GRID_STEPS)
	var x1 : int = clampi(ix + 1, 0, GRID_STEPS)
	var z0 : int = clampi(iz - 1, 0, GRID_STEPS)
	var z1 : int = clampi(iz + 1, 0, GRID_STEPS)
	var dx : float = (heights[iz * row + x1] - heights[iz * row + x0]) \
					 / (step * float(x1 - x0))
	var dz : float = (heights[z1 * row + ix] - heights[z0 * row + ix]) \
					 / (step * float(z1 - z0))
	return sqrt(dx * dx + dz * dz)


# GLSL-style smoothstep: maps x from [edge0..edge1] → [0..1] with smooth curve.
static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t : float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# Factory helper for noise instances.
static func _make(p_seed: int, freq: float,
				  fractal: FastNoiseLite.FractalType,
				  octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed            = p_seed
	n.frequency       = freq
	n.fractal_type    = fractal
	n.fractal_octaves = octaves
	return n
