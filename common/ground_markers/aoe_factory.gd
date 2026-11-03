## 地面预警形状工厂（对应 fru_sim 的 CircleAoe / LineAoe / DonutAoe 类库）
## 全部返回 MeshInstance3D，材质为不受光半透明色块
class_name AoeFactory
extends RefCounted

const Y_LIFT := 0.03   # 略微抬高，避免与地面 z-fighting


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


## 圆形：用扁圆柱当贴地圆盘
static func circle(center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = Vector3(center.x, Y_LIFT, center.z)
	return mi


## 直线（带宽度的矩形）：用扁盒子
static func line(from: Vector3, ang_deg: float, width: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.02, length)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	var a := deg_to_rad(ang_deg)
	var dir := Vector3(sin(a), 0.0, -cos(a))
	mi.position = Vector3(from.x, Y_LIFT, from.z) + dir * (length * 0.5)
	mi.rotation.y = -a
	return mi


## 环形（月环）：手工三角环
static func ring(center: Vector3, inner: float, outer: float, color: Color, seg: int = 64) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var i0 := Vector3(sin(a0) * inner, 0.0, -cos(a0) * inner)
		var o0 := Vector3(sin(a0) * outer, 0.0, -cos(a0) * outer)
		var i1 := Vector3(sin(a1) * inner, 0.0, -cos(a1) * inner)
		var o1 := Vector3(sin(a1) * outer, 0.0, -cos(a1) * outer)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = Vector3(center.x, Y_LIFT, center.z)
	return mi


## 设置透明度（0~1）
static func set_alpha(mi: MeshInstance3D, alpha: float) -> void:
	if mi and mi.material_override is StandardMaterial3D:
		var m: StandardMaterial3D = mi.material_override
		var c := m.albedo_color
		c.a = clampf(alpha, 0.0, 1.0)
		m.albedo_color = c
