## 玩家：简单位移控制 + 胶囊体占位（后续换成 FBX 角色）
class_name PlayerController
extends Node3D

signal died(cause: String)

var walk_speed: float = 6.0
var sprint_mul: float = 1.5
var wall_x: float = 19.3
var body_r: float = 0.45

var _mesh: MeshInstance3D
var _facing: Node3D
var alive := true

func _ready() -> void:
	# 占位身体：胶囊
	_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.42
	cap.height = 1.7
	_mesh.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.95, 1.0)
	m.roughness = 0.5
	_mesh.material_override = m
	_mesh.position.y = 0.85
	add_child(_mesh)

	# 朝向指示（一个小锥）
	_facing = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.7
	_facing.mesh = cone
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.72, 1.0)
	fm.emission_enabled = true
	fm.emission = Color(0.15, 0.35, 0.6)
	_facing.material_override = fm
	_facing.rotation.x = -PI * 0.5
	_facing.position = Vector3(0, 1.0, -0.85)
	add_child(_facing)

	# 脚下投影
	var sh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	sh.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sh.material_override = sm
	sh.position.y = 0.02
	add_child(sh)


func _process(delta: float) -> void:
	if not alive:
		return
	var dx := 0.0
	var dz := 0.0
	if Input.is_key_pressed(KEY_W): dz -= 1.0
	if Input.is_key_pressed(KEY_S): dz += 1.0
	if Input.is_key_pressed(KEY_A): dx -= 1.0
	if Input.is_key_pressed(KEY_D): dx += 1.0

	var len := sqrt(dx * dx + dz * dz)
	if len > 0.001:
		dx /= len
		dz /= len
		var sp := walk_speed
		if Input.is_key_pressed(KEY_SHIFT):
			sp *= sprint_mul
		position.x += dx * sp * delta
		position.z += dz * sp * delta
		# 朝向：+Z 是南，面向移动方向
		rotation.y = atan2(dx, dz)

	# 撞墙
	var r := Vector2(position.x, position.z).length()
	if r > wall_x:
		var k := wall_x / r
		position.x *= k
		position.z *= k
		kill("撞到场地边缘的墙壁")


func kill(cause: String) -> void:
	if not alive:
		return
	alive = false
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.45, 0.45)
	died.emit(cause)


func reset(pos: Vector3 = Vector3.ZERO) -> void:
	alive = true
	position = pos
	rotation.y = 0.0
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.92, 0.95, 1.0)


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)
