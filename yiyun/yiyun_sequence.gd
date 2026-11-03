## 一运：序列 + 判定（对应 fru_sim 的 yiyun_seq + position_coords）
## 时间轴全部来自实测（见 data/yiyun.json 注释）
class_name YiyunSequence
extends Node3D

signal finished_clear()
signal finished_dead(cause: String)

var D: YiyunData
var hud: YiyunHud
var camera: Camera3D
var player: PlayerController

var layout: Dictionary = {}
var running := false
var t := 0.0
var speed := 1.0
var cause := ""

var _hazards: Array = []          # 判定条目
var _fired: Array = []            # 是否已结算
var _nodes: Array = []            # 对应的可视 MeshInstance3D
var _boss_nodes := {}             # key -> Node3D（占位方块，之后换 FBX）
var ui_font: Font = null          # 由 main 注入，用于 Label3D 中文

const C_LINE := Color(0.88, 0.70, 0.23, 0.28)
const C_MOON := Color(0.24, 0.86, 0.52, 0.22)
const C_FEATHER := Color(0.24, 0.86, 0.52, 0.26)
const C_DASH := Color(1.0, 0.37, 0.37, 0.26)


func setup(d: YiyunData, h: YiyunHud, cam: Camera3D, p: PlayerController) -> void:
	D = d
	hud = h
	camera = cam
	player = p
	_build_boss_placeholders()


func _build_boss_placeholders() -> void:
	for key in D.bosses.keys():
		var info: Dictionary = D.bosses[key]
		var node := Node3D.new()
		node.name = "Boss_" + key

		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h: float = float(info.get("height", 6.0))
		box.size = Vector3(h * 0.45, h * 0.7, h * 0.45)
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.html(String(info.get("color", "#ffffff")))
		m.roughness = 0.6
		mi.material_override = m
		mi.position.y = h * 0.35
		node.add_child(mi)

		# 名字
		var lb := Label3D.new()
		lb.text = String(info.get("name", key))
		lb.font_size = 48
		lb.pixel_size = 0.01
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position.y = h * 0.78
		if ui_font != null:
			lb.font = ui_font
		node.add_child(lb)

		node.visible = false
		add_child(node)
		_boss_nodes[key] = node


## 开始一局
func start(rng: RandomNumberGenerator, keep_layout: bool = false) -> void:
	if not keep_layout or layout.is_empty():
		layout = YiyunData.gen_layout(rng)
	cause = ""
	t = 0.0
	running = true
	_clear_visuals()
	_build_hazards()
	player.reset(Vector3.ZERO)
	hud.hide_all_casts()


func _clear_visuals() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_hazards.clear()
	_fired.clear()


func _build_hazards() -> void:
	var T: Dictionary = D.timeline
	var G: Dictionary = D.geo
	var H: Dictionary = D.hit
	var titan_pos := YiyunData.pol(float(G.titan_r), float(layout.titan_deg))
	var ifrit_pos := YiyunData.pol(float(G.ifrit_r), float(layout.ifrit_deg))
	var garuda_pos := YiyunData.pol(float(G.garuda_r), float(layout.garuda_deg))

	# 五路地裂 ①：5 条线，45° 间隔，留 90° 空档
	for i in 5:
		var ang: float = float(layout.fan1) + 90.0 + i * 45.0
		_add_line(titan_pos, ang, float(H.line_w), float(H.line_len),
			float(T.t_cast1), float(T.t_hit1), "泰坦五路地裂 ①", C_LINE)
	# 五路地裂 ②：空档转 90°
	for i in 5:
		var ang: float = float(layout.fan2) + 90.0 + i * 45.0
		_add_line(titan_pos, ang, float(H.line_w), float(H.line_len),
			float(T.t_cast2), float(T.t_hit2), "泰坦五路地裂 ②", C_LINE)
	# 深红旋风
	_add_line(ifrit_pos, float(layout.ifrit_deg), float(H.dash_w), float(H.dash_len),
		float(T.g_cast), float(T.g_hit), "深红旋风", C_DASH)
	# 月环
	_add_ring(garuda_pos, float(H.moon_in), float(H.moon_out),
		float(T.g_cast), float(T.moon_hit), "邪轮旋风·月环", C_MOON)
	# 飞翎雨（施法瞬间锁定脚下）
	_add_circle(Vector3.ZERO, float(H.feather_r), float(T.f_cast), float(T.f_hit),
		"飞翎雨", C_FEATHER, true)


func _add_line(from: Vector3, ang: float, w: float, ln: float, t0: float, th: float,
		nm: String, color: Color) -> void:
	var mi := AoeFactory.line(from, ang, w, ln, color)
	mi.visible = false
	add_child(mi)
	_nodes.append(mi)
	_hazards.append({"kind": "line", "from": from, "ang": ang, "w": w, "len": ln,
		"t0": t0, "t": th, "name": nm})
	_fired.append(false)


func _add_ring(c: Vector3, rin: float, rout: float, t0: float, th: float,
		nm: String, color: Color) -> void:
	var mi := AoeFactory.ring(c, rin, rout, color)
	mi.visible = false
	add_child(mi)
	_nodes.append(mi)
	_hazards.append({"kind": "ring", "c": c, "r_in": rin, "r_out": rout,
		"t0": t0, "t": th, "name": nm})
	_fired.append(false)


func _add_circle(c: Vector3, r: float, t0: float, th: float, nm: String, color: Color,
		lock: bool) -> void:
	var mi := AoeFactory.circle(c, r, color)
	mi.visible = false
	add_child(mi)
	_nodes.append(mi)
	_hazards.append({"kind": "circle", "c": c, "r": r, "t0": t0, "t": th,
		"name": nm, "lock": lock, "armed": false})
	_fired.append(false)


func _process(delta: float) -> void:
	if D == null:
		return

	_place_bosses()
	_update_visuals()

	if not running:
		return

	if player == null or not player.alive:
		return

	t += delta * speed

	# 结算判定
	for i in _hazards.size():
		var h: Dictionary = _hazards[i]
		# 飞翎雨锁点
		if bool(h.get("lock", false)) and not bool(h.get("armed", false)) and t >= float(h.t0):
			h["c"] = Vector3(player.position.x, 0.0, player.position.z)
			h["armed"] = true
			_hazards[i] = h
			_nodes[i].position = Vector3(player.position.x, 0.03, player.position.z)
		if _fired[i] or t < float(h.t):
			continue
		_fired[i] = true
		if _hit(h, Vector2(player.position.x, player.position.z)):
			_die(String(h.name))
			return

	# 通过
	if t >= float(D.timeline.end):
		running = false
		finished_clear.emit()

	_update_hud()


func _place_bosses() -> void:
	var G: Dictionary = D.geo
	var appeared := t >= float(D.timeline.appear)
	var positions := {
		"garuda": YiyunData.pol(float(G.garuda_r), float(layout.get("garuda_deg", 45.0))),
		"ifrit": YiyunData.pol(float(G.ifrit_r), float(layout.get("ifrit_deg", 135.0))),
		"titan": YiyunData.pol(float(G.titan_r), float(layout.get("titan_deg", 0.0))),
	}
	if appeared:
		positions["ultima"] = YiyunData.pol(float(G.ultima_r), float(layout.get("ultima_deg", 225.0)))
	else:
		positions["ultima"] = YiyunData.pol(7.2, 180.0)   # 读条时在正北

	for key in _boss_nodes:
		var node: Node3D = _boss_nodes[key]
		var show := true if key == "ultima" else appeared
		node.visible = show
		if show and positions.has(key):
			var p: Vector3 = positions[key]
			node.position = Vector3(p.x, 0.0, p.z)


func _update_visuals() -> void:
	for i in _hazards.size():
		var h: Dictionary = _hazards[i]
		var mi: MeshInstance3D = _nodes[i]
		if t < float(h.t0):
			mi.visible = false
			continue
		mi.visible = true
		var span: float = maxf(0.15, float(h.t) - float(h.t0))
		var k := clampf((t - float(h.t0)) / span, 0.0, 1.0)
		var after := t - float(h.t)
		var a := 0.10 + 0.26 * k
		if after >= 0.0:
			a = 0.08 + 0.42 * maxf(0.0, 1.0 - after / 0.35)
		AoeFactory.set_alpha(mi, a)


func _hit(h: Dictionary, p: Vector2) -> bool:
	var br := float(D.hit.body_r)
	match String(h.kind):
		"line":
			var a := deg_to_rad(float(h.ang))
			var dir := Vector2(sin(a), -cos(a))
			var q: Vector2 = p - Vector2(h.from.x, h.from.z)
			var proj := q.dot(dir)
			if proj < -br or proj > float(h.len) + br:
				return false
			var perp := Vector2(-dir.y, dir.x)
			return absf(q.dot(perp)) < float(h.w) * 0.5 + br
		"ring":
			var d := (p - Vector2(h.c.x, h.c.z)).length()
			return d > float(h.r_in) - br and d < float(h.r_out) + br
		"circle":
			if not bool(h.get("armed", false)):
				return false
			var d2 := (p - Vector2(h.c.x, h.c.z)).length()
			return d2 < float(h.r) + br
	return false


func _die(why: String) -> void:
	running = false
	cause = why
	player.kill(why)
	finished_dead.emit(why)


func _update_hud() -> void:
	hud.set_clock(t)
	var T: Dictionary = D.timeline
	var txt := ""
	if t < float(T.appear):
		txt = "本体读条 · 追击的究极幻想"
	elif t < float(T.g_cast):
		txt = "快跑位：看迦楼罗朝向 → 定安全点"
	elif t < float(T.g_hit):
		txt = "读条中：邪轮旋风 / 深红旋风"
	elif t < float(T.t_hit1):
		txt = "一段判定 → 等第二安全点"
	elif t < float(T.t_hit2):
		txt = "五路① 已过 → 跟着转"
	elif t < float(T.f_hit):
		txt = "躲开五路②"
	else:
		txt = "飞翎雨 → 离开原地"
	hud.set_state(txt)

	# 读条（贴在 Boss 头顶）
	var casts := _casts_now()
	for key in _boss_nodes.keys():
		var node: Node3D = _boss_nodes[key]
		var info: Dictionary = D.bosses.get(key, {})
		var h: float = float(info.get("height", 6.0))
		var show: bool = casts.has(key) and node.visible
		var pname := "" if not show else String(casts[key].name)
		var prog := 0.0 if not show else float(casts[key].p)
		var col := Color.html(String(info.get("color", "#ffffff")))
		var head := node.position + Vector3(0, h, 0)
		hud.set_cast(key, pname, prog, head, col, show)


## 当前正在读条的技能（与实测时间轴一致）
func _casts_now() -> Dictionary:
	var T: Dictionary = D.timeline
	var out := {}
	if t < float(T.appear):
		out["ultima"] = {"name": "追击的究极幻想", "p": t / maxf(0.1, float(T.appear))}
	if t >= float(T.g_cast) and t < float(T.moon_hit):
		out["garuda"] = {"name": "邪轮旋风", "p": (t - float(T.g_cast)) / (float(T.moon_hit) - float(T.g_cast))}
	if t >= float(T.f_cast) and t < float(T.f_hit):
		out["garuda"] = {"name": "飞翎雨", "p": (t - float(T.f_cast)) / (float(T.f_hit) - float(T.f_cast))}
	if t >= float(T.g_cast) and t < float(T.g_hit):
		out["ifrit"] = {"name": "深红旋风", "p": (t - float(T.g_cast)) / (float(T.g_hit) - float(T.g_cast))}
	if t >= float(T.t_cast1) and t < float(T.t_hit1):
		out["titan"] = {"name": "地裂 ×5", "p": (t - float(T.t_cast1)) / (float(T.t_hit1) - float(T.t_cast1))}
	if t >= float(T.t_cast2) and t < float(T.t_hit2):
		out["titan"] = {"name": "地裂 ×5", "p": (t - float(T.t_cast2)) / (float(T.t_hit2) - float(T.t_cast2))}
	return out
