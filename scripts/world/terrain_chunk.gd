class_name TerrainChunk
extends Node3D

var _mesh_instance : MeshInstance3D
var _static_body   : StaticBody3D


func setup(mesh: ArrayMesh) -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh

	# Display the vertex colors baked by TerrainGenerator.surface_color()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.metallic = 0.0
	_mesh_instance.material_override = mat

	add_child(_mesh_instance)


func enable_collision() -> void:
	if _static_body != null:
		return
	_static_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = _mesh_instance.mesh.create_trimesh_shape()
	_static_body.add_child(shape)
	add_child(_static_body)


func disable_collision() -> void:
	if _static_body == null:
		return
	_static_body.queue_free()
	_static_body = null
