extends Node

const CENTER := Vector3(0, -1024, 0)
const RADIUS := 1024.0


func surface_up(world_pos: Vector3) -> Vector3:
	var offset := world_pos - CENTER
	if offset.length_squared() < 0.001:
		return Vector3.UP
	return offset.normalized()


func project_on_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	return vector - plane_normal * vector.dot(plane_normal)


func align_basis_to_surface(forward: Vector3, up: Vector3) -> Basis:
	var body_right := forward.cross(up).normalized()
	var corrected_forward := up.cross(body_right).normalized()
	return Basis(body_right, up, -corrected_forward).orthonormalized()
